import sync from '../../Resources/SyncCore.js';
export const LIMIT=300;
export function fresh(){return {schema:1,projects:[],tabs:[],deleted:[],deletedProjects:[],open:[],selected:null,project:null,positions:{},settings:{locale:'ru',theme:'system'}};}
export function restore(value){
 const clean=sync.clean(value);const originals=new Map(value.tabs.map(t=>[t.id.toLowerCase(),t]));for(const t of clean.tabs){const language=originals.get(t.id)?.language;if(["auto","text","markdown","html","sql","kafka","json","javascript","python","css"].includes(language))t.language=language;}const ids=new Set(clean.tabs.map(t=>t.id));const projects=new Set(clean.projects.map(p=>p.id));
 const positions={};for(const t of clean.tabs){const n=value.positions?.[t.id];if(Number.isInteger(n)&&n>=0)positions[t.id]=Math.min(n,t.text.length);}
 return {...fresh(),...clean,positions,open:[...new Set(value.open||[])].filter(id=>ids.has(id)),selected:ids.has(value.selected)?value.selected:null,project:projects.has(value.project)?value.project:null,settings:{locale:value.settings?.locale==='en'?'en':'ru',theme:['system','light','dark'].includes(value.settings?.theme)?value.settings.theme:'system',githubRepository:typeof value.settings?.githubRepository==='string'&&/^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$/.test(value.settings.githubRepository)?value.settings.githubRepository:'notepad-notes'}};
}
export function group(m){return m.tabs.filter(t=>t.projectId===m.project);}
export function nextName(names,base){let n=1;while(names.includes(`${base} ${n}`))n++;return `${base} ${n}`;}
export function title(m,t){const p=m.projects.find(p=>p.id===t.projectId);return p?p.title+'.'+t.title:t.title;}
export function createNote(m,uuid=()=>crypto.randomUUID()){
 if(m.tabs.length>=LIMIT)throw Error('note_limit');
 const t={id:uuid(),projectId:m.project,title:nextName(group(m).map(t=>t.title),m.settings.locale==='en'?'Note':'Заметка'),text:''};m.tabs.push(t);m.open.push(t.id);m.selected=t.id;return t;
}
export function closeNote(m,id){m.open=m.open.filter(x=>x!==id);if(m.selected===id)m.selected=group(m).find(t=>m.open.includes(t.id))?.id||null;}
export function removeNote(m,id){if(!m.tabs.some(t=>t.id===id))return;closeNote(m,id);m.tabs=m.tabs.filter(t=>t.id!==id);m.deleted=[...new Set([...m.deleted,id])];}
export function removeProject(m,id){if(!m.projects.some(p=>p.id===id))return;for(const t of m.tabs.filter(t=>t.projectId===id))removeNote(m,t.id);m.projects=m.projects.filter(p=>p.id!==id);m.deletedProjects=[...new Set([...(m.deletedProjects||[]),id])];if(m.project===id){m.project=null;m.selected=group(m).find(t=>m.open.includes(t.id))?.id||null;}}
export function selectProject(m,id){m.project=id;m.selected=group(m).find(t=>m.open.includes(t.id))?.id||null;}
export function portable(m){return sync.clean(m);}
export function importNotes(m,source,uuid=()=>crypto.randomUUID()){
 const incoming=sync.clean(source);if(m.tabs.length+incoming.tabs.length>LIMIT||m.projects.length+incoming.projects.length>100)throw Error('note_limit');
 // Import as copies: importing an old backup never overwrites newer work or clears tombstones.
 const projects=new Map();for(const p of incoming.projects){const id=uuid();projects.set(p.id,id);m.projects.push({id,title:p.title});}
 for(const t of incoming.tabs){const id=uuid();m.tabs.push({...t,id,projectId:projects.get(t.projectId)||null});}
 return incoming.tabs.length;
}

export function applySnapshot(m,snapshot){const clean=sync.clean(snapshot),old=new Map(m.tabs.map(t=>[t.id,t]));const next=restore({...m,...clean,tabs:clean.tabs.map(t=>({...old.get(t.id),...t})),open:[...m.open,...clean.tabs.filter(t=>!old.has(t.id)).map(t=>t.id)]});if(!next.tabs.some(t=>t.id===next.selected&&next.open.includes(t.id))){const first=next.tabs.find(t=>t.projectId===next.project&&next.open.includes(t.id));next.selected=first?.id||null;if(!m.tabs.length&&next.tabs.length){next.selected=next.tabs[0].id;next.project=next.tabs[0].projectId;}}return next;}
