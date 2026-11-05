// Keep installer assets for the two newest stable semantic versions only.
const {execFileSync}=require('node:child_process');
const pattern=/\.(zip|exe|AppImage|deb)(\.sha256)?$/;
const tuple=tag=>/^v\d+\.\d+\.\d+$/.test(tag)?tag.slice(1).split('.').map(Number):null;
function plan(releases,current){
 const stable=releases.filter(r=>!r.draft&&!r.prerelease&&tuple(r.tag_name)).sort((a,b)=>{const x=tuple(a.tag_name),y=tuple(b.tag_name);for(let i=0;i<3;i++)if(x[i]!==y[i])return y[i]-x[i];return 0;});
 if(stable[0]?.tag_name!==current)throw Error('Cleanup requires the newest published stable release.');
 const assets=stable[0].assets||[];
 for(const suffix of ['universal.zip','Windows-x64-Setup.exe','Linux-x64.AppImage','Linux-x64.deb']){
  const file=assets.find(a=>a.name.endsWith(suffix)&&a.size>0);
  if(!file||!assets.some(a=>a.name===file.name+'.sha256'&&a.size>0))throw Error('Newest release is incomplete; keeping old installers.');
 }
 return stable.slice(2).flatMap(r=>(r.assets||[]).filter(a=>pattern.test(a.name)).map(a=>({tag:r.tag_name,id:a.id,name:a.name})));
}
module.exports={plan};
if(require.main===module){
 const repo=process.env.GH_REPO,version=process.env.RELEASE_VERSION;
 if(!repo||!version)throw Error('GH_REPO and RELEASE_VERSION are required');
 const gh=args=>execFileSync('gh',args,{encoding:'utf8'});
 const releases=JSON.parse(gh(['api',`repos/${repo}/releases?per_page=100`,'--paginate','--slurp'])).flat();
 const removals=plan(releases,`v${version}`);
 for(const item of removals){console.log(`Removing ${item.tag}: ${item.name}`);gh(['api','--silent','--method','DELETE',`repos/${repo}/releases/assets/${item.id}`]);}
 console.log(`Removed ${removals.length} old installer/checksum assets. Tags, notes and source archives retained.`);
}
