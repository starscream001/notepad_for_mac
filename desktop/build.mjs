import {build} from 'esbuild';
import {mkdir,copyFile,readFile,writeFile} from 'node:fs/promises';
await mkdir('ui',{recursive:true});
await build({entryPoints:['src/renderer.js'],bundle:true,outfile:'ui/renderer.js',format:'esm',platform:'browser',target:'chrome140',minify:true});
for(const name of ['index.html','style.css']) await copyFile(`src/${name}`,`ui/${name}`);
await copyFile('../Resources/Palettes.json','ui/palettes.json');
await copyFile('../LICENSE','LICENSE');

await copyFile('../Resources/AppIcon.png','ui/icon.png');
const formatOptions={bundle:true,platform:'browser',target:'safari16',minify:true,nodePaths:['./node_modules'],legalComments:'eof'};
await build({...formatOptions,entryPoints:['../Formatting/formatter.mjs'],outfile:'../Resources/Vendor/formatter.js',format:'iife',globalName:'NotepadFormatting'});
await build({...formatOptions,entryPoints:['src/format-worker.js'],outfile:'ui/format-worker.js',format:'iife'});
await writeFile('../Resources/Vendor/sql-formatter-LICENSE.txt','sql-formatter 15.9.0\n\n'+await readFile('node_modules/sql-formatter/LICENSE','utf8')+'\n\nnearley 2.20.1 (bundled parser runtime)\n\n'+await readFile('node_modules/nearley/LICENSE.txt','utf8'));

await copyFile('../Resources/Vendor/sql-formatter-LICENSE.txt','ui/sql-formatter-LICENSE.txt');
