import sync from '../../Resources/SyncCore.js';
const sha=s=>{if(typeof s!=='string'||!/^[0-9a-f]{40,64}$/.test(s))throw Error('invalid_response');return s;};
export const repositoryName=name=>{if(typeof name!=='string'||!/^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$/.test(name)||name.endsWith('.git'))throw Error('invalid_repository');return name;};
export async function synchronize({owner,repo,token,base,local,request,uuid=()=>crypto.randomUUID()}){
 repositoryName(repo);if(!/^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(owner))throw Error('invalid_repository');local=sync.clean(local);
 const prefix=`https://api.github.com/repos/${owner}/${repo}`,api=(path,method='GET',data)=>request(prefix+path,{method,data,token,stage:path===''?'repository':path.startsWith('/git/ref/heads/')?'branch':method==='PATCH'?'update':method==='POST'?'write':'read'});
 const info=await api('');if(info.private!==true||info.owner?.login?.toLowerCase()!==owner.toLowerCase()||typeof info.default_branch!=='string')throw Error('private_repository_required');
 const branch=encodeURIComponent(info.default_branch),ref=await api('/git/ref/heads/'+branch),head=sha(ref.object?.sha),commit=await api('/git/commits/'+head),treeSHA=sha(commit.tree?.sha),tree=await api('/git/trees/'+treeSHA+'?recursive=1');
 if(tree.truncated||!Array.isArray(tree.tree))throw Error('invalid_response');let remote=sync.empty();const entry=tree.tree.find(e=>e.path==='.notepad/snapshot.json');
 if(entry){if(entry.type!=='blob'||!Number.isInteger(entry.size)||entry.size>5242880)throw Error('invalid_snapshot');const blob=await api('/git/blobs/'+sha(entry.sha));if(blob.encoding!=='base64'||typeof blob.content!=='string'||blob.content.length>8*1024*1024)throw Error('invalid_snapshot');try{const bytes=Uint8Array.from(atob(blob.content.replace(/\s/g,'')),c=>c.charCodeAt(0));if(bytes.length>5242880)throw Error();remote=sync.clean(JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes)));}catch{throw Error('invalid_snapshot');}}
 const result=sync.merge(base,local,remote,Array.from({length:300},uuid)),content=sync.stringify(result.snapshot);if(content===sync.stringify(remote))return {...result,head};
 const blob=await api('/git/blobs','POST',{content,encoding:'utf-8'}),nextTree=await api('/git/trees','POST',{base_tree:treeSHA,tree:[{path:'.notepad/snapshot.json',mode:'100644',type:'blob',sha:sha(blob.sha)}]}),next=await api('/git/commits','POST',{message:'Sync Notepad notes',tree:sha(nextTree.sha),parents:[head]});
 await api('/git/refs/heads/'+branch,'PATCH',{sha:sha(next.sha),force:false});return {...result,head:next.sha};
}
