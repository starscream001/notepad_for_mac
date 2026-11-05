// Portable content only: local paths, secrets and UI metadata are excluded.
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const fail=()=>{throw Error('Invalid Notepad sync snapshot');};
const id=x=>typeof x==='string'&&UUID.test(x)?x.toLowerCase():fail();
const title=x=>typeof x==='string'&&x.trim()&&x.length<=200&&!/[\x00-\x1f]/.test(x)?x:fail();
function encode({projects,tabs}){
 if(!Array.isArray(projects)||projects.length>100||!Array.isArray(tabs)||tabs.length>300)fail();
 const ps=projects.map(p=>({id:id(p.id),title:title(p.title)})).sort((a,b)=>a.id.localeCompare(b.id));
 const ids=new Set(ps.map(p=>p.id));if(ids.size!==ps.length)fail();
 const files={};const ts=tabs.map(t=>{const key=id(t.id),projectId=t.projectId==null?null:id(t.projectId);if(projectId&&!ids.has(projectId))fail();if(typeof t.text!=='string'||Buffer.byteLength(t.text)>20*1024*1024)fail();const file=`notepad/tabs/${key}.txt`;if(Object.hasOwn(files,file))fail();files[file]=t.text;return {id:key,projectId,title:title(t.title),file};}).sort((a,b)=>a.id.localeCompare(b.id));
 files['notepad/manifest.json']=JSON.stringify({schema:1,projects:ps,tabs:ts},null,2)+'\n';
 return Object.fromEntries(Object.entries(files).sort(([a],[b])=>a.localeCompare(b)));
}
function decode(files){
 if(!files||typeof files!=='object'||typeof files['notepad/manifest.json']!=='string'||Buffer.byteLength(files['notepad/manifest.json'])>1024*1024)fail();
 let m;try{m=JSON.parse(files['notepad/manifest.json']);}catch{fail();}if(m.schema!==1||!Array.isArray(m.tabs)||m.tabs.length>300)fail();
 const model={projects:m.projects,tabs:m.tabs.map(t=>{const key=id(t.id);if(t.file!==`notepad/tabs/${key}.txt`||!Object.hasOwn(files,t.file))fail();return {id:key,projectId:t.projectId,title:t.title,text:files[t.file]};})};
 const checked=encode(model),canonical=JSON.parse(checked['notepad/manifest.json']);return {projects:canonical.projects,tabs:canonical.tabs.map(t=>({id:t.id,projectId:t.projectId,title:t.title,text:checked[t.file]}))};
}
module.exports={encode,decode};
