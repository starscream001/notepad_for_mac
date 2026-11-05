/* Shared by Electron and JavaScriptCore. No filesystem, network, or secrets. */
var NotepadSync = (function(){
 'use strict';
 var uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
 function invalid(){throw Error('invalid_snapshot');}
 function bytes(s){var n=0;for(var i=0;i<s.length;i++){var c=s.charCodeAt(i);if(c<128)n++;else if(c<2048)n+=2;else if(c>=55296&&c<=56319&&i+1<s.length&&s.charCodeAt(i+1)>=56320&&s.charCodeAt(i+1)<=57343){n+=4;i++;}else n+=3;}return n;}
 function identity(s){if(typeof s!=='string'||!uuid.test(s.toLowerCase()))invalid();return s.toLowerCase();}
 function title(s){if(typeof s!=='string'||!s.trim()||s.length>200||/[\x00-\x1f]/.test(s))invalid();return s;}
 function clean(value){
  if(!value||value.schema!==1||!Array.isArray(value.projects)||value.projects.length>100||!Array.isArray(value.tabs)||value.tabs.length>300)invalid();
  var deleted=(value.deleted||[]).map(identity);if(deleted.length>10000)invalid();deleted=Array.from(new Set(deleted)).sort();
  var deletedProjects=(value.deletedProjects||[]).map(identity);if(deletedProjects.length>10000)invalid();deletedProjects=Array.from(new Set(deletedProjects)).sort();
  var ps={},ts={};var projects=value.projects.map(function(p){var id=identity(p.id);if(ps[id]||deletedProjects.indexOf(id)!==-1)invalid();ps[id]=true;return {id:id,title:title(p.title)};});
  var tabs=value.tabs.map(function(t){var id=identity(t.id),p=t.projectId==null?null:identity(t.projectId);if(ts[id]||deleted.indexOf(id)!==-1||(p&&!ps[p])||typeof t.text!=='string'||bytes(t.text)>1048576)invalid();ts[id]=true;return {id:id,projectId:p,title:title(t.title),text:t.text};});
  projects.sort(function(a,b){return a.id<b.id?-1:a.id>b.id?1:0;});tabs.sort(function(a,b){return a.id<b.id?-1:a.id>b.id?1:0;});var result={schema:1,projects:projects,tabs:tabs,deleted:deleted};if(deletedProjects.length)result.deletedProjects=deletedProjects;if(bytes(JSON.stringify(result))>5242880)invalid();return result;
 }
 function empty(){return {schema:1,projects:[],tabs:[],deleted:[]};}
 function same(a,b){return JSON.stringify(a)===JSON.stringify(b);}
 function field(b,l,r){if(same(l,r)||same(b,r))return {value:l};if(same(b,l))return {value:r};return {value:l,conflict:true};}
 function map(items){var m={};items.forEach(function(x){m[x.id]=x;});return m;}
 function merge(base,local,remote,newIds){
  base=clean(base||empty());local=clean(local);remote=clean(remote);var b=map(base.tabs),l=map(local.tabs),r=map(remote.tabs),projects=[],tabs=[],conflicts=0,used={};local.tabs.concat(remote.tabs).forEach(function(t){used[t.id]=true;});
  var deleted=Array.from(new Set(local.deleted.concat(remote.deleted))).sort();
  var deletedProjects=Array.from(new Set((local.deletedProjects||[]).concat(remote.deletedProjects||[]))).sort();
  var bp=map(base.projects),lp=map(local.projects),rp=map(remote.projects);Object.keys(Object.assign({},lp,rp)).sort().forEach(function(id){if(deletedProjects.indexOf(id)!==-1)return;var a=lp[id],z=rp[id];if(!a||!z){projects.push(a||z);return;}var result=field(bp[id]&&bp[id].title,a.title,z.title);projects.push({id:id,title:result.conflict?(a.title+' / '+z.title).slice(0,200):result.value});if(result.conflict)conflicts++;});
  Object.keys(Object.assign({},l,r)).sort().forEach(function(id){var a=l[id],z=r[id];if(deleted.indexOf(id)!==-1){var survivor=local.deleted.indexOf(id)!==-1?z:a;if(survivor&&(!b[id]||!same(survivor,b[id]))){var copy;do{copy=identity(newIds.shift());}while(used[copy]);used[copy]=true;tabs.push({id:copy,projectId:survivor.projectId,title:survivor.title.slice(0,175)+' (delete conflict)',text:survivor.text});conflicts++;}return;}if(!a||!z){tabs.push(a||z);return;}var merged={id:id},conflict=false;['title','text','projectId'].forEach(function(k){var result=field(b[id]&&b[id][k],a[k],z[k]);merged[k]=result.value;conflict=conflict||!!result.conflict;});tabs.push(merged);if(conflict){var key;do{key=identity(newIds.shift());}while(used[key]);used[key]=true;tabs.push({id:key,projectId:z.projectId,title:(z.title.slice(0,175)+' (GitHub conflict)'),text:z.text});conflicts++;}});
  // Concurrent edits survive project deletion in Without project; never resurrect the deleted group.
  tabs.forEach(function(t){if(deletedProjects.indexOf(t.projectId)!==-1)t.projectId=null;});
  return {snapshot:clean({schema:1,projects:projects,tabs:tabs,deleted:deleted,deletedProjects:deletedProjects}),conflicts:conflicts};
 }
 return {clean:clean,empty:empty,merge:merge,stringify:function(x){var text=JSON.stringify(clean(x),null,2)+'\n';if(bytes(text)>5242880)invalid();return text;},mergeJSON:function(b,l,r,ids){return JSON.stringify(merge(JSON.parse(b),JSON.parse(l),JSON.parse(r),JSON.parse(ids)));}};
})();
if(typeof module!=='undefined')module.exports=NotepadSync;
