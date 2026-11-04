import {build} from 'esbuild';
import {mkdir,copyFile} from 'node:fs/promises';
await mkdir('ui',{recursive:true});
await build({entryPoints:['src/renderer.js'],bundle:true,outfile:'ui/renderer.js',format:'esm',platform:'browser',target:'chrome140',minify:true});
for(const name of ['index.html','style.css']) await copyFile(`src/${name}`,`ui/${name}`);
await copyFile('../Resources/Palettes.json','ui/palettes.json');
await copyFile('../LICENSE','LICENSE');

await copyFile('../Resources/AppIcon.png','ui/icon.png');
const formatOptions={bundle:true,platform:'browser',target:'safari16',minify:true,nodePaths:['./node_modules'],legalComments:'eof'};
await build({...formatOptions,entryPoints:['../Formatting/formatter.mjs'],outfile:'../Resources/Vendor/formatter.js',format:'iife',globalName:'NotepadFormatting'});
await build({...formatOptions,entryPoints:['src/format-worker.js'],outfile:'ui/format-worker.js',format:'iife'});
await copyFile('node_modules/sql-formatter/LICENSE','../Resources/Vendor/sql-formatter-LICENSE.txt');

await copyFile('node_modules/sql-formatter/LICENSE','ui/sql-formatter-LICENSE.txt');
