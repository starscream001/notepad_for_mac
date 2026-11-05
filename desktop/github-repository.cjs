// Privileged process only; no tokens or response bodies are returned to renderer.
async function createPrivateRepository({name,confirmed,login,token,signal,fetcher=fetch}){
 if(confirmed!==true)throw Error('confirmation_required');
 if(typeof name!=='string'||!/^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$/.test(name)||name.endsWith('.git'))throw Error('invalid_name');
 if(typeof login!=='string'||!/^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(login)||!token)throw Error('unauthorized');
 let response;try{response=await fetcher('https://api.github.com/user/repos',{method:'POST',redirect:'error',signal:AbortSignal.any([signal,AbortSignal.timeout(20000)]),headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','Content-Type':'application/json','X-GitHub-Api-Version':'2026-03-10','User-Agent':'Notepad-Desktop'},body:JSON.stringify({name,private:true,auto_init:true,description:'Private Notepad notes',has_issues:false,has_projects:false,has_wiki:false})});}catch{throw Error('creation_outcome_unknown');}
 if(response.status!==201){await response.body?.cancel();throw Error(response.status===422?'name_unavailable':response.status===401?'unauthorized':response.status===403?'permission_required':'creation_outcome_unknown');}
 let data;try{const reader=response.body.getReader(),chunks=[];let size=0;try{while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>65536)throw Error();chunks.push(value);}}finally{await reader.cancel().catch(()=>{});}data=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw Error('creation_outcome_unknown');}
 if(data.private!==true||data.owner?.login?.toLowerCase()!==login.toLowerCase()||data.name!==name||!Number.isSafeInteger(data.id)||data.id<1)throw Error('unexpected_repository');
 return {id:data.id,owner:data.owner.login,name,private:true,url:`https://github.com/${login}/${name}`};
}
module.exports={createPrivateRepository};
