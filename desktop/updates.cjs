// Windows updater: GitHub metadata is the trust root; no renderer-provided URLs or paths.
const fs=require('node:fs');const fsp=require('node:fs/promises');const path=require('node:path');const crypto=require('node:crypto');
const {newer,assetFor}=require('./core.cjs');
const REPO='https://github.com/starscream001/notepad_for_mac',MAX=512*1024*1024;
function candidate(release,current){
 if(!release||release.draft||release.prerelease||!newer(release.tag_name,current))return null;
 if(!/^v\d+\.\d+\.\d+$/.test(release.tag_name))throw Error('Invalid release version.');
 const version=release.tag_name.slice(1),name=assetFor('win32',version),asset=release.assets?.find(a=>a.name===name);
 if(!asset)throw Error('Update installer is missing.');
 const url=REPO+'/releases/download/v'+version+'/'+name;
 if(asset.browser_download_url!==url||!Number.isSafeInteger(asset.size)||asset.size<=0||asset.size>MAX||!/^sha256:[a-f0-9]{64}$/i.test(asset.digest||''))throw Error('Update metadata could not be verified.');
 return {version,name,url,size:asset.size,sha256:asset.digest.slice(7).toLowerCase()};
}
function allowedURL(value){try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password&&['github.com','release-assets.githubusercontent.com','objects.githubusercontent.com'].includes(u.hostname)&&(!u.port||u.port==='443');}catch{return false;}}
async function responseFor(url,signal,request=fetch){
 for(let redirects=0;redirects<=8;redirects++){
  if(!allowedURL(url))throw Error('Unexpected update download server.');
  const response=await request(url,{redirect:'manual',signal,headers:{'User-Agent':'Notepad-Desktop-Updater'}});
  if([301,302,303,307,308].includes(response.status)){const location=response.headers.get('location');await response.body?.cancel();if(!location)throw Error('Invalid download redirect.');url=new URL(location,url).href;continue;}
  if(!response.ok){await response.body?.cancel();throw Error(`Update download failed (HTTP ${response.status}).`);}return response;
 }
 throw Error('Too many update redirects.');
}
async function verified(file,item){
 const stat=await fsp.lstat(file);if(!stat.isFile()||stat.isSymbolicLink()||stat.size!==item.size)throw Error('Update size does not match.');
 const hash=crypto.createHash('sha256');for await(const chunk of fs.createReadStream(file))hash.update(chunk);
 if(hash.digest('hex')!==item.sha256)throw Error('Update SHA256 does not match.');return true;
}
async function download(item,root,{signal,onProgress=()=>{},request=fetch}={}){
 await fsp.mkdir(root,{recursive:true,mode:0o700});
 // Only our updater-owned staging directories, older than a week.
 for(const entry of await fsp.readdir(root,{withFileTypes:true})){
  if(!entry.isDirectory()||!entry.name.startsWith('download-'))continue;
  const old=path.join(root,entry.name);
  try{if(Date.now()-(await fsp.lstat(old)).mtimeMs>7*86400000)await fsp.rm(old,{recursive:true,force:true});}catch{}
 }
 const dir=await fsp.mkdtemp(path.join(root,'download-')),file=path.join(dir,item.name),partial=file+'.part';
 let handle;
 try{
  const response=await responseFor(item.url,signal,request),length=response.headers.get('content-length');
  if(length&&Number(length)!==item.size){await response.body?.cancel();throw Error('Update size does not match.');}
  if(!response.body)throw Error('Empty update response.');
  handle=await fsp.open(partial,'wx',0o600);const hash=crypto.createHash('sha256');let received=0;
  for await(const chunk of response.body){signal?.throwIfAborted();received+=chunk.length;if(received>item.size||received>MAX)throw Error('Update download is too large.');hash.update(chunk);await handle.writeFile(chunk);onProgress(received,item.size);}
  signal?.throwIfAborted();
  if(received!==item.size)throw Error('Update download is incomplete.');
  if(hash.digest('hex')!==item.sha256)throw Error('Update SHA256 does not match.');
  await handle.sync();await handle.close();handle=null;await fsp.rename(partial,file);return file;
 }catch(error){await handle?.close();await fsp.rm(dir,{recursive:true,force:true});throw error;}
}
async function install(prepared,{save,open,quit}){
 await verified(prepared.file,prepared.item);
 await save();
 const error=await open(prepared.file);
 if(error)throw Error(error);
 quit();
}
module.exports={candidate,allowedURL,responseFor,download,verified,install};
