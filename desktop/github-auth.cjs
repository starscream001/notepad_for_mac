// GitHub OAuth Device Flow. Tokens never leave the main process.
const {setTimeout:delay}=require('node:timers/promises');
const VERIFY='https://github.com/login/device';
const validClient=id=>typeof id==='string'&&/^[A-Za-z0-9_.-]{10,100}$/.test(id);
const fail=code=>Object.assign(new Error(code),{authCode:code});
function profileOf(value){
 if(!Number.isSafeInteger(value?.id)||value.id<=0||typeof value.login!=='string'||!/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$/.test(value.login))throw fail('invalid_response');
 return {id:value.id,login:value.login,name:typeof value.name==='string'?value.name.replace(/\s+/g,' ').slice(0,100):null,url:'https://github.com/'+value.login};
}
function deviceOf(value){
 if(typeof value?.device_code!=='string'||!/^[A-Za-z0-9_-]{10,200}$/.test(value.device_code)||typeof value.user_code!=='string'||!/^[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(value.user_code)||value.verification_uri!==VERIFY||!Number.isInteger(value.expires_in)||value.expires_in<1||value.expires_in>1800||!Number.isInteger(value.interval)||value.interval<1||value.interval>60)throw fail('invalid_response');
 return value;
}
function tokenOf(value){
 if(value?.token_type?.toLowerCase()!=='bearer'||typeof value.access_token!=='string'||!/^[A-Za-z0-9_-]{10,1024}$/.test(value.access_token)||typeof value.scope!=='string'||value.scope.trim()!=='')throw fail('invalid_response');
 if(value.expires_in!==undefined&&(!Number.isSafeInteger(value.expires_in)||value.expires_in<1||value.expires_in>31536000))throw fail('invalid_response');
 return value.access_token;
}
class GitHubAuth {
 constructor({clientID,storage,emit=()=>{},fetcher=fetch,sleep=(ms,signal)=>delay(ms,undefined,{signal}),now=()=>Date.now(),openBrowser=()=>{}}){
  Object.assign(this,{clientID,storage,emit,fetcher,sleep,now,openBrowser});this.generation=0;this.queue=Promise.resolve();this.state={phase:validClient(clientID)?'signedOut':'unconfigured'};this.credentials=null;
 }
 publish(state){this.state=state;this.emit({...state});return {...state};}
 serial(fn){const next=this.queue.then(fn);this.queue=next.catch(()=>{});return next;}
 async request(url,body,signal,token){
  try{
   const response=await this.fetcher(url,{method:body?'POST':'GET',headers:{Accept:'application/json','User-Agent':'Notepad-Desktop',...(body?{'Content-Type':'application/x-www-form-urlencoded'}:{}),...(token?{Authorization:'Bearer '+token,'X-GitHub-Api-Version':'2022-11-28'}:{})},...(body?{body:new URLSearchParams(body).toString()}:{}),redirect:'error',signal:AbortSignal.any([signal,AbortSignal.timeout(15000)])});
   if(response.status===401)throw fail('unauthorized');if(!response.ok)throw fail(response.status===403||response.status===429?'rate_limit':'network');
   if(Number(response.headers.get('content-length'))>65536)throw fail('invalid_response');
   const reader=response.body.getReader();let length=0;const chunks=[];try{while(true){const {done,value}=await reader.read();if(done)break;length+=value.length;if(length>65536)throw fail('invalid_response');chunks.push(value);}}finally{await reader.cancel().catch(()=>{});}
   return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  }catch(e){if(signal.aborted)throw fail('cancelled');throw e.authCode?e:fail('network');}
 }
 async status(){
  if(!validClient(this.clientID))return {...this.state};
  if(!this.initialized){this.initialized=true;const epoch=this.generation;
   try{await this.serial(async()=>{const saved=await this.storage.read();if(epoch!==this.generation)return;if(saved&&saved.provider==='github-app'&&saved.clientID===this.clientID){tokenOf({access_token:saved.token,token_type:'bearer',scope:''});const profile=profileOf(saved.profile);if(saved.expiresAt&&saved.expiresAt<=this.now()){await this.storage.remove();return;}this.credentials=saved;this.publish({phase:'connected',profile});}});}
   catch{if(epoch===this.generation)this.publish({phase:'error',error:'storage'});}
  }return {...this.state};
 }
 cancel(){this.generation++;this.controller?.abort();this.creationController?.abort();this.controller=null;this.publish(this.credentials?{phase:'connected',profile:this.credentials.profile}:{phase:validClient(this.clientID)?'signedOut':'unconfigured'});}
 async start(){
  await this.status();if(this.credentials)return {...this.state};if(!validClient(this.clientID))return this.publish({phase:'unconfigured'});
  this.cancel();this.credentials=null;const epoch=this.generation,controller=new AbortController();this.controller=controller;const signal=controller.signal;
  this.publish({phase:'starting'});
  this.run(epoch,signal).catch(e=>{if(epoch===this.generation)this.publish({phase:'error',error:e.authCode||'network'});}).finally(()=>{if(epoch===this.generation)this.controller=null;});return {...this.state};
 }
 async run(epoch,signal){
  // Test secure storage before opening the browser; never fall back to plaintext.
  if(!await this.storage.available())throw fail('storage');
  const device=deviceOf(await this.request('https://github.com/login/device/code',{client_id:this.clientID},signal));
  if(epoch!==this.generation)return;const expiresAt=this.now()+device.expires_in*1000;
  this.publish({phase:'waiting',userCode:device.user_code,verificationURL:VERIFY,expiresAt});
  try{await this.openBrowser(VERIFY);}catch{if(epoch===this.generation)this.publish({...this.state,browserError:true});}
  let interval=device.interval;
  while(epoch===this.generation){
   if(this.now()+interval*1000>=expiresAt)throw fail('expired_token');
   await this.sleep(interval*1000,signal);if(epoch!==this.generation)return;
   const result=await this.request('https://github.com/login/oauth/access_token',{client_id:this.clientID,device_code:device.device_code,grant_type:'urn:ietf:params:oauth:grant-type:device_code'},signal);
   if(epoch!==this.generation)return;if(this.now()>=expiresAt)throw fail('expired_token');
   if(result.error==='authorization_pending')continue;
   if(result.error==='slow_down'){interval+=5;continue;}
   if(result.error)throw fail(['access_denied','expired_token','incorrect_client_credentials','device_flow_disabled'].includes(result.error)?result.error:'invalid_response');
   const token=tokenOf(result);const profile=profileOf(await this.request('https://api.github.com/user',null,signal,token));
   const credentials={provider:'github-app',clientID:this.clientID,token,profile,expiresAt:result.expires_in?this.now()+result.expires_in*1000:null};
   await this.serial(async()=>{if(epoch!==this.generation)return;try{await this.storage.write(credentials);}catch{throw fail('storage');}if(epoch!==this.generation){await this.storage.remove();return;}this.credentials=credentials;this.publish({phase:'connected',profile});});return;
  }
 }
 async createRepository(name,confirmed){
  await this.status();if(!this.credentials)throw fail('unauthorized');if(this.creating)throw fail('busy');this.creating=true;
  const epoch=this.generation,controller=new AbortController();this.creationController=controller;
  try{const {createPrivateRepository}=require('./github-repository.cjs');const repo=await createPrivateRepository({name,confirmed,login:this.credentials.profile.login,token:this.credentials.token,signal:controller.signal,fetcher:this.fetcher});if(epoch!==this.generation)throw fail('creation_outcome_unknown');return repo;}
  finally{this.creating=false;this.creationController=null;}
 }
 async disconnect(){this.cancel();this.credentials=null;const epoch=this.generation;this.publish({phase:'signingOut'});try{await this.serial(()=>this.storage.remove());if(epoch===this.generation)this.publish({phase:validClient(this.clientID)?'signedOut':'unconfigured'});}catch{if(epoch===this.generation)this.publish({phase:'error',error:'storage'});}}
 async refresh(){
  await this.status();if(!this.credentials)return {...this.state};this.cancel();const epoch=this.generation,controller=new AbortController();this.controller=controller;
  try{const profile=profileOf(await this.request('https://api.github.com/user',null,controller.signal,this.credentials.token));await this.serial(async()=>{if(epoch!==this.generation)return;const credentials={...this.credentials,profile};try{await this.storage.write(credentials);}catch{throw fail('storage');}if(epoch!==this.generation){await this.storage.remove();return;}this.credentials=credentials;this.publish({phase:'connected',profile});});}
  catch(e){if(epoch===this.generation){if(e.authCode==='unauthorized'){await this.disconnect();if(epoch+1===this.generation)this.publish({phase:'error',error:'unauthorized'});}else this.publish({phase:'connected',profile:this.credentials.profile,error:e.authCode||'network'});}}
  finally{if(epoch===this.generation)this.controller=null;}return {...this.state};
 }
}
module.exports={GitHubAuth,profileOf,deviceOf,tokenOf,validClient,VERIFY};
