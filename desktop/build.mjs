import {build} from 'esbuild';
import {mkdir,copyFile} from 'node:fs/promises';
await mkdir('ui',{recursive:true});
await build({entryPoints:['src/renderer.js'],bundle:true,outfile:'ui/renderer.js',format:'esm',platform:'browser',target:'chrome140',minify:true});
for(const name of ['index.html','style.css']) await copyFile(`src/${name}`,`ui/${name}`);
await copyFile('../LICENSE','LICENSE');

await copyFile('../Resources/AppIcon.png','ui/icon.png');
