const {test}=require('node:test');const assert=require('node:assert/strict');
const {plan}=require('../../scripts/release-retention.cjs');
const names=['Notepad-Mac-universal.zip','Notepad-Desktop-0.7.0-Windows-x64-Setup.exe','Notepad-Desktop-0.7.0-Linux-x64.AppImage','Notepad-Desktop-0.7.0-Linux-x64.deb'];
const assets=names.flatMap((name,i)=>[{name,id:i*2,size:100},{name:name+'.sha256',id:i*2+1,size:100}]);
const release=(tag_name,more={})=>({tag_name,assets,draft:false,prerelease:false,...more});
test('retention keeps two newest stable releases, ignores draft/prerelease and non-installers',()=>{
 const old=release('v0.5.0',{assets:[...assets,{name:'notes.txt',id:99}]});
 const result=plan([old,release('v0.6.0'),release('v0.7.0'),release('v1.0.0',{draft:true}),release('latest',{prerelease:true})],'v0.7.0');
 assert.equal(result.length,8);assert.ok(result.every(x=>x.tag==='v0.5.0'&&x.name!=='notes.txt'));
});
test('retention refuses stale publication or incomplete newest installers',()=>{
 assert.throws(()=>plan([release('v0.7.0'),release('v0.6.0')],'v0.6.0'));
 assert.throws(()=>plan([release('v0.7.0',{assets:assets.slice(1)})],'v0.7.0'));
});
