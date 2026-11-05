const {test}=require('node:test'),assert=require('node:assert/strict');const p=require('../projects.cjs');
test('legacy session migrates into Without project without losing text or settings',()=>{
 const old={tabs:[{id:'a',title:'SQL',text:'несохранено 🦊',selection:5}],selected:'a',settings:{theme:'dark'}};
 const migrated=p.normalize(old);assert.deepEqual(migrated.tabs[0],{...old.tabs[0],projectId:null});assert.equal(migrated.tabs[0].text,old.tabs[0].text);assert.deepEqual(migrated.settings,old.settings);assert.deepEqual(migrated.projects,[]);
});
test('projects keep independent tabs, names and remembered selections after JSON round trip',()=>{
 const m=p.normalize(JSON.parse(JSON.stringify({projects:[{id:'p1',title:'Работа',selected:'b'},{id:'p2',title:'Дом',selected:'c'}],selectedProject:'p1',tabs:[{id:'a',title:'Заметка 1',projectId:'p1',text:'A'},{id:'b',title:'Запрос.sql',projectId:'p1',text:'B'},{id:'c',title:'Заметка 1',projectId:'p2',text:'C'}]})));
 assert.equal(p.chosen(m.tabs,'p1',m.projects[0].selected).id,'b');assert.equal(p.chosen(m.tabs,'p2',m.projects[1].selected).id,'c');assert.equal(p.visible(m.tabs,'p1').length,2);assert.equal(p.title(m.tabs[1],m.projects),'Работа.Запрос.sql');
 m.projects[0].title='База';assert.equal(p.title(m.tabs[1],m.projects),'База.Запрос.sql');assert.equal(m.tabs[1].text,'B');
});
test('names fill unused sequence, orphan tabs are retained and invalid projects rejected',()=>{
 assert.equal(p.nextName(['Заметка 1','Заметка 3'],'Заметка'),'Заметка 2');
 assert.equal(p.nextName(['Заметка 2'],'Заметка'),'Заметка 1');
 assert.equal(p.nextName(p.visible([{title:'Заметка 1',projectId:'other'}],'current').map(t=>t.title),'Заметка'),'Заметка 1');
 assert.equal(p.normalize({tabs:[{id:'x',projectId:'missing',text:'keep'}]}).tabs[0].projectId,null);
 assert.throws(()=>p.normalize({projects:[{id:'a',title:'A'},{id:'a',title:'B'}]}));assert.equal(p.chosen([],null,'none'),null);
});
