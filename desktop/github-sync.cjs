const core=require('node:fs').existsSync(require('node:path').join(__dirname,'sync-core.cjs'))?require('./sync-core.cjs'):require('../Resources/SyncCore.js');
const crypto=require('node:crypto');
const validSha=s=>typeof s==='string'&&/^[a-f0-9]{40,64}$/.test(s);
async function synchronize({owner,repo,token,base,local,signal,fetcher=fetch}){
 if(!/^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(owner)||!/^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$/.test(repo))throw Error('invalid_repository');
 local=core.clean(local);const prefix=`https://api.github.com/repos/${owner}/${repo}`;
 async function request(path,method='GET',body){
  let res;try{res=await fetcher(prefix+path,{method,redirect:'error',signal:AbortSignal.any([signal,AbortSignal.timeout(30000)]),headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','Content-Type':'application/json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'Notepad-Desktop'},...(body?{body:JSON.stringify(body)}:{})});}catch{throw Error(signal.aborted?'cancelled':'network');}
  if(!res.ok){await res.body?.cancel();throw Error([409,422].includes(res.status)?'remote_changed':res.status===401?'unauthorized':res.status===403?'permission_required':'network');}
  const reader=res.body.getReader(),chunks=[];let size=0;try{while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>8*1024*1024)throw Error('snapshot_too_large');chunks.push(value);}}finally{await reader.cancel().catch(()=>{});}try{return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks)));}catch{throw Error('invalid_response');}
 }
 const info=await request('');if(info.private!==true||info.owner?.login?.toLowerCase()!==owner.toLowerCase()||typeof info.default_branch!=='string')throw Error('private_repository_required');
 const branch=info.default_branch,ref=await request('/git/ref/heads/'+encodeURIComponent(branch));const head=ref.object?.sha;if(!validSha(head))throw Error('invalid_response');
 const commit=await request('/git/commits/'+head),treeSha=commit.tree?.sha;if(!validSha(treeSha))throw Error('invalid_response');
 // Read a single fixed path at the pinned commit; never follow external download_url.
 const tree=await request('/git/trees/'+treeSha+'?recursive=1');if(tree.truncated||!Array.isArray(tree.tree))throw Error('invalid_response');
 const entry=tree.tree.find(e=>e.path==='.notepad/snapshot.json');let remote=core.empty();
 if(entry){if(entry.type!=='blob'||!validSha(entry.sha)||entry.size>5242880)throw Error('invalid_snapshot');const blob=await request('/git/blobs/'+entry.sha);if(blob.encoding!=='base64'||typeof blob.content!=='string'||blob.content.length>8*1024*1024)throw Error('invalid_snapshot');remote=core.clean(JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(Buffer.from(blob.content.replace(/\s/g,''),'base64'))));}
 const result=core.merge(base||core.empty(),local,remote,Array.from({length:300},()=>crypto.randomUUID()));const content=core.stringify(result.snapshot);
 if(content===core.stringify(remote))return {...result,head};
 const blob=await request('/git/blobs','POST',{content,encoding:'utf-8'});if(!validSha(blob.sha))throw Error('invalid_response');
 const newTree=await request('/git/trees','POST',{base_tree:treeSha,tree:[{path:'.notepad/snapshot.json',mode:'100644',type:'blob',sha:blob.sha}]});if(!validSha(newTree.sha))throw Error('invalid_response');
 const next=await request('/git/commits','POST',{message:'Sync Notepad notes',tree:newTree.sha,parents:[head]});if(!validSha(next.sha))throw Error('invalid_response');
 await request('/git/refs/heads/'+encodeURIComponent(branch),'PATCH',{sha:next.sha,force:false});return {...result,head:next.sha};
}
module.exports={synchronize};
