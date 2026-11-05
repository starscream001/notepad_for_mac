import {build} from 'esbuild';import {mkdir,copyFile,readFile} from 'node:fs/promises';
const pkg=JSON.parse(await readFile('package.json','utf8'));await mkdir('www',{recursive:true});
await build({entryPoints:['src/app.js'],bundle:true,format:'esm',outfile:'www/app.js',minify:true,target:['safari16','chrome108'],define:{__VERSION__:JSON.stringify(pkg.version)}});
const css=await build({entryPoints:['src/style.css'],outfile:'www/style.css',minify:true,logLevel:'silent'});if(css.warnings.length)throw Error('Invalid CSS');
await copyFile('src/index.html','www/index.html');await copyFile('../Resources/AppIcon.png','www/icon.png');
