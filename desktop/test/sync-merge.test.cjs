const {test}=require('node:test'),assert=require('node:assert/strict'),core=require('../../Resources/SyncCore.js');
const a='11111111-1111-4111-8111-111111111111',b='22222222-2222-4222-8222-222222222222';const snapshot=text=>({schema:1,projects:[],tabs:[{id:a,projectId:null,title:'Note',text}]});
test('merge preserves independent edits, renames, and remote-only notes',()=>{const base=snapshot('base'),l=snapshot('local'),r=snapshot('base');r.tabs[0].title='Renamed';r.tabs.push({id:b,projectId:null,title:'Other',text:'remote'});const m=core.merge(base,l,r,[]);assert.equal(m.conflicts,0);assert.equal(m.snapshot.tabs[0].text,'local');assert.equal(m.snapshot.tabs[0].title,'Renamed');assert.equal(m.snapshot.tabs.length,2);});
test('conflicting changes preserve both texts and become stable after sync',()=>{const m=core.merge(snapshot('base'),snapshot('local'),snapshot('remote'),[b]);assert.equal(m.conflicts,1);assert.deepEqual(m.snapshot.tabs.map(t=>t.text),['local','remote']);assert.deepEqual(core.merge(m.snapshot,m.snapshot,m.snapshot,[]).snapshot,m.snapshot);});
test('first download retains local notes; closure never silently deletes remote content',()=>{assert.equal(core.merge(null,core.empty(),snapshot('remote'),[]).snapshot.tabs[0].text,'remote');assert.equal(core.merge(snapshot('old'),core.empty(),snapshot('remote'),[]).snapshot.tabs.length,1);});
test('portable schema discards local paths and rejects bad identity or oversized inputs',()=>{const s=snapshot('🦊');s.tabs[0].path='/private';s.token='SECRET';assert.ok(!core.stringify(s).includes('/private'));assert.ok(!core.stringify(s).includes('SECRET'));s.tabs[0].id='../../x';assert.throws(()=>core.clean(s));});
test('explicit deletion propagates while concurrent edits survive as conflict copies',()=>{const base=core.clean(snapshot('base')),deleted={schema:1,projects:[],tabs:[],deleted:[a]};assert.equal(core.merge(base,deleted,base,[]).snapshot.tabs.length,0);const remoteDeleted=core.merge(base,base,deleted,[]).snapshot;assert.deepEqual(remoteDeleted.deleted,[a]);assert.equal(remoteDeleted.tabs.length,0);const conflict=core.merge(base,snapshot('edited'),deleted,[b]);assert.equal(conflict.snapshot.tabs[0].id,b);assert.equal(conflict.snapshot.tabs[0].text,'edited');assert.deepEqual(conflict.snapshot.deleted,[a]);});
test('project deletion propagates in both directions, with concurrent edits rescued outside the project',()=>{
 const p='33333333-3333-4333-8333-333333333333';
 const base={schema:1,projects:[{id:p,title:'Work'}],tabs:[{id:a,projectId:p,title:'Заметка 1',text:'base'}]};
 const deleted={schema:1,projects:[],tabs:[],deleted:[a],deletedProjects:[p]};
 for(const [l,r]of [[base,deleted],[deleted,base]]){const m=core.merge(base,l,r,[]).snapshot;assert.deepEqual(m.projects,[]);assert.deepEqual(m.tabs,[]);assert.deepEqual(m.deletedProjects,[p]);assert.deepEqual(core.merge(m,m,m,[]).snapshot,m);}
 const edited=structuredClone(base);edited.tabs[0].text='unsynced edits';
 const m=core.merge(base,deleted,edited,[b]).snapshot;assert.equal(m.projects.length,0);assert.equal(m.tabs[0].projectId,null);assert.equal(m.tabs[0].text,'unsynced edits');assert.equal(m.tabs[0].id,b);
 assert.deepEqual(core.clean(JSON.parse(core.stringify(m))),m);
 assert.throws(()=>core.clean({...base,deletedProjects:[p]}));
});
