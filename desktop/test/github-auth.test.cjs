const {test}=require('node:test'),assert=require('node:assert/strict');
const {GitHubAuth,deviceOf,tokenOf,VERIFY}=require('../github-auth.cjs');
const {credentialStore}=require('../github-storage.cjs');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const clientID='Iv1.testclient123',token='gho_TEST_ONLY_TOKEN_123456789',profile={id:42,login:'test-user',name:'Test'};
const device={device_code:'test_device_code_1234567890',user_code:'ABCD-1234',verification_uri:VERIFY,expires_in:900,interval:5};
const reply={access_token:token,token_type:'bearer',scope:''};
const tick=()=>new Promise(resolve=>setImmediate(resolve));
async function until(fn){for(let i=0;i<100;i++){if(fn())return;await tick();}assert.fail('State did not settle');}
function fixture(responses,extra={}){
 let stored=null,now=1000;const requests=[],states=[],waits=[],opened=[];
 const storage={available:async()=>true,read:async()=>stored,write:async value=>{stored=value;},remove:async()=>{stored=null;}};
 const auth=new GitHubAuth({clientID,storage,emit:s=>states.push(s),now:()=>now,sleep:async(ms,signal)=>{waits.push(ms);if(signal.aborted)throw Error('abort');now+=ms;},openBrowser:async url=>opened.push(url),fetcher:async(url,options)=>{requests.push({url,options});const value=responses.shift();if(value instanceof Error)throw value;return new Response(JSON.stringify(value),{status:200});},...extra});
 return {auth,storage,requests,states,waits,opened,stored:()=>stored};
}
test('device sign-in requests profile only; token stays in protected storage, never UI events',async()=>{
 const f=fixture([device,{error:'authorization_pending'},{error:'slow_down'},reply,profile]);
 await f.auth.start();await until(()=>f.auth.state.phase==='connected');
 assert.deepEqual(f.waits,[5000,5000,10000]);assert.deepEqual(f.opened,[VERIFY]);assert.equal(f.stored().token,token);assert.equal(f.auth.state.profile.url,'https://github.com/test-user');
 const body=new URLSearchParams(f.requests[0].options.body);assert.equal(body.has('scope'),false);assert.equal(body.has('client_secret'),false);
 assert.equal(f.requests.at(-1).options.headers.Authorization,'Bearer '+token);assert.equal(JSON.stringify(f.states).includes(token),false);assert.equal(JSON.stringify(f.states).includes(device.device_code),false);
 assert.ok(f.requests.every(r=>r.options.redirect==='error'));assert.equal(f.requests.length,5);
 const restored=fixture([],{storage:f.storage});assert.equal((await restored.auth.status()).profile.login,'test-user');assert.equal(restored.requests.length,0);
 await restored.auth.disconnect();assert.equal(f.stored(),null);assert.equal(restored.auth.state.phase,'signedOut');
});
test('denied and expired codes stop polling without storing an account',async()=>{
 for(const [response,error]of [[{error:'access_denied'},'access_denied'],[{error:'expired_token'},'expired_token']]){
  const f=fixture([device,response]);await f.auth.start();await until(()=>f.auth.state.phase==='error');assert.equal(f.auth.state.error,error);assert.equal(f.stored(),null);assert.equal(f.requests.length,2);
 }
 const f=fixture([{...device,expires_in:4}]);await f.auth.start();await until(()=>f.auth.state.phase==='error');assert.equal(f.auth.state.error,'expired_token');assert.equal(f.requests.length,1);
});
test('cancel during polling prevents profile requests and persistence, even if network finishes late',async()=>{
 let release;const pending=new Promise(r=>{release=r;});let calls=0;
 const f=fixture([],{fetcher:async()=>{calls++;return new Response(JSON.stringify(calls===1?device:await pending));}});
 await f.auth.start();await until(()=>calls===2);f.auth.cancel();release(reply);await tick();await tick();assert.equal(f.auth.state.phase,'signedOut');assert.equal(f.stored(),null);assert.equal(calls,2);
});
test('disconnect racing a credential write removes the late write',async()=>{
 let release,entered=false,saved=null;const gate=new Promise(r=>{release=r;});
 const storage={available:async()=>true,read:async()=>null,write:async value=>{entered=true;await gate;saved=value;},remove:async()=>{saved=null;}};
 const f=fixture([device,reply,profile],{storage});await f.auth.start();await until(()=>entered);const disconnected=f.auth.disconnect();release();await disconnected;await tick();assert.equal(saved,null);assert.equal(f.auth.state.phase,'signedOut');
});
test('unsafe URL, broader scopes and malformed profile cannot establish an account',async()=>{
 assert.throws(()=>deviceOf({...device,verification_uri:'https://evil.example/login'}));assert.throws(()=>tokenOf({...reply,scope:'read:user,repo'}));
 const f=fixture([device,reply,{...profile,login:'../../settings'}]);await f.auth.start();await until(()=>f.auth.state.phase==='error');assert.equal(f.stored(),null);assert.equal(f.auth.state.error,'invalid_response');
});
test('network/secure storage failures stay actionable and cannot expose raw errors or start browser without secure storage',async()=>{
 const unavailable=fixture([],{storage:{read:async()=>null,available:async()=>false}});await unavailable.auth.start();await until(()=>unavailable.auth.state.phase==='error');assert.equal(unavailable.auth.state.error,'storage');assert.equal(unavailable.opened.length,0);assert.equal(unavailable.requests.length,0);
 const f=fixture([Error('private '+token)]);await f.auth.start();await until(()=>f.auth.state.phase==='error');assert.equal(f.auth.state.error,'network');assert.equal(JSON.stringify(f.states).includes(token),false);
 const absent=fixture([],{clientID:''});assert.equal((await absent.auth.start()).phase,'unconfigured');assert.equal(absent.requests.length,0);
});
test('revoked account is removed on explicit connection check; offline profile is retained',async()=>{
 const f=fixture([device,reply,profile]);await f.auth.start();await until(()=>f.auth.state.phase==='connected');
 f.auth.fetcher=async()=>{throw Error('offline');};await f.auth.refresh();assert.equal(f.auth.state.phase,'connected');assert.equal(f.auth.state.error,'network');assert.equal(f.stored().token,token);
 f.auth.fetcher=async()=>new Response('{}',{status:401});await f.auth.refresh();assert.equal(f.auth.state.error,'unauthorized');assert.equal(f.stored(),null);
});
test('credential file contains ciphertext and Linux plaintext fallback is refused',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'notepad-auth-'));let safe=true;
 const crypto={isAsyncEncryptionAvailable:async()=>safe,encryptStringAsync:async()=>Buffer.from('ciphertext'),decryptStringAsync:async()=>({result:JSON.stringify({token}),shouldReEncrypt:false}),isEncryptionAvailable:()=>true,getSelectedStorageBackend:()=> 'basic_text'};
 try{const store=credentialStore({safeStorage:crypto,directory:dir,platform:'win32'});await store.write({token});assert.equal(fs.readFileSync(path.join(dir,'github-account.enc'),'utf8'),'ciphertext');assert.equal((await store.read()).token,token);safe=false;await assert.rejects(store.write({token}));await store.remove();assert.equal(await store.read(),null);
 const linux=credentialStore({safeStorage:crypto,directory:dir,platform:'linux'});assert.equal(await linux.available(),false);await assert.rejects(linux.write({token}));assert.equal(fs.existsSync(path.join(dir,'github-account.enc')),false);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
