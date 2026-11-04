const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs/promises'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const {candidate,allowedURL,responseFor,download,verified}=require('../updates.cjs');
const bytes=Buffer.from('synthetic installer fixture — not executable'),digest=crypto.createHash('sha256').update(bytes).digest('hex');
const asset={name:'Notepad-Desktop-0.8.0-Windows-x64-Setup.exe',size:bytes.length,digest:'sha256:'+digest,browser_download_url:'https://github.com/starscream001/notepad_for_mac/releases/download/v0.8.0/Notepad-Desktop-0.8.0-Windows-x64-Setup.exe'};
const release={tag_name:'v0.8.0',assets:[asset],draft:false,prerelease:false},item=candidate(release,'0.7.3');
test('only newer stable Windows installer with exact repository URL, size and digest is accepted',()=>{
 assert.equal(candidate(release,'0.8.0'),null);assert.equal(candidate({...release,draft:true},'0.7.3'),null);
 for(const patch of [{digest:null},{size:600*1024*1024},{size:-1},{browser_download_url:'https://github.com/attacker/Setup.exe'}])assert.throws(()=>candidate({...release,assets:[{...asset,...patch}]},'0.7.3'));
});
test('redirect policy rejects insecure servers, credentials and unexpected hosts',async()=>{
 for(const url of ['http://github.com/a','https://github.com.evil.test/a','https://x:secret@github.com/a','https://github.com:8443/a'])assert.equal(allowedURL(url),false);
 const malicious=async()=>new Response(null,{status:302,headers:{location:'https://evil.test/installer.exe'}});
 await assert.rejects(responseFor(item.url,undefined,malicious),/Unexpected/);
 await assert.rejects(responseFor(item.url,undefined,async()=>new Response(null,{status:302,headers:{location:item.url}})),/Too many/);
});
async function temporary(fn){const root=await fs.mkdtemp(path.join(os.tmpdir(),'notepad-update-'));try{await fn(root);}finally{await fs.rm(root,{recursive:true,force:true});}}
test('streamed download is verified and tampering before install is detected',()=>temporary(async root=>{
 let progress=0;const file=await download(item,root,{request:async()=>new Response(bytes,{headers:{'content-length':String(bytes.length)}}),onProgress:n=>progress=n});
 assert.equal(progress,bytes.length);assert.deepEqual(await fs.readFile(file),bytes);assert.equal(await verified(file,item),true);
 await fs.writeFile(file,Buffer.alloc(bytes.length));await assert.rejects(verified(file,item),/SHA256/);
}));
test('wrong digest, truncation, overflow and interrupted stream leave no installer or partial file',()=>temporary(async root=>{
 for(const data of [Buffer.alloc(bytes.length),bytes.subarray(0,4),Buffer.concat([bytes,bytes])]){
  await assert.rejects(download(item,root,{request:async()=>new Response(data)}));assert.deepEqual(await fs.readdir(root),[]);
 }
 const stream=new ReadableStream({start(c){c.enqueue(bytes.subarray(0,3));c.error(Error('network interrupted'));}});
 await assert.rejects(download(item,root,{request:async()=>new Response(stream)}),/interrupted/);assert.deepEqual(await fs.readdir(root),[]);
}));
test('cancelled transfer cannot leave an executable or report success',()=>temporary(async root=>{
 const controller=new AbortController();
 await assert.rejects(download(item,root,{signal:controller.signal,request:async()=>new Response(bytes),onProgress:()=>controller.abort()}));
 assert.deepEqual(await fs.readdir(root),[]);
}));
test('installation verifies again and never launches or quits after save/launch failure',()=>temporary(async root=>{
 const file=await download(item,root,{request:async()=>new Response(bytes)}),prepared={item,file},events=[];
 const {install}=require('../updates.cjs');
 await assert.rejects(install(prepared,{save:()=>{throw Error('disk full');},open:()=>events.push('open'),quit:()=>events.push('quit')}),/disk full/);assert.deepEqual(events,[]);
 await assert.rejects(install(prepared,{save:()=>events.push('save'),open:()=>{events.push('open');return 'launch blocked';},quit:()=>events.push('quit')}),/launch blocked/);assert.deepEqual(events,['save','open']);
 events.length=0;await install(prepared,{save:()=>events.push('save'),open:()=>{events.push('open');return '';},quit:()=>events.push('quit')});assert.deepEqual(events,['save','open','quit']);
}));
