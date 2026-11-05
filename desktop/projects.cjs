// Virtual workspaces; documents remain ordinary tabs. No directory scans or background services.
function normalize(model){
 const projects=Array.isArray(model.projects)?model.projects:[];
 if(projects.length>100||projects.some(p=>typeof p.id!=='string'||typeof p.title!=='string'||!p.title.trim()||p.title.length>80)||new Set(projects.map(p=>p.id)).size!==projects.length)throw Error('Invalid projects');
 const ids=new Set(projects.map(p=>p.id));
 return {...model,projects,selectedProject:ids.has(model.selectedProject)?model.selectedProject:null,tabs:(model.tabs||[]).map(t=>({...t,projectId:ids.has(t.projectId)?t.projectId:null}))};
}
function visible(tabs,id){return tabs.filter(t=>(t.projectId||null)===(id||null));}
function title(tab,projects){const p=projects.find(p=>p.id===tab.projectId);return p?p.title+'.'+tab.title:tab.title;}
function nextName(existing,base){let n=1;while(existing.includes(`${base} ${n}`))n++;return `${base} ${n}`;}
function chosen(tabs,projectId,remembered){const group=visible(tabs,projectId);return group.find(t=>t.id===remembered)||group[0]||null;}
module.exports={normalize,visible,title,nextName,chosen};
