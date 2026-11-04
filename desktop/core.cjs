const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const MAX_BYTES = 20_000_000;
function decode(data) {
  let encoding='UTF-8', text;
  if(data[0]===0xff && data[1]===0xfe){encoding='UTF-16 LE';text=new TextDecoder('utf-16le',{fatal:true}).decode(data.subarray(2));}
  else if(data[0]===0xfe && data[1]===0xff){encoding='UTF-16 BE';text=new TextDecoder('utf-16be',{fatal:true}).decode(data.subarray(2));}
  else {encoding=data[0]===0xef&&data[1]===0xbb&&data[2]===0xbf?'UTF-8 BOM':'UTF-8';text=new TextDecoder('utf-8',{fatal:true}).decode(data);}
  if(text.includes('\0'))throw Error('Бинарный файл не поддерживается.');
  const ending=text.includes('\r\n')?'CRLF':text.includes('\r')?'CR':'LF';
  return {text:text.replace(/\r\n|\r/g,'\n'),encoding,ending};
}
function encode(text,encoding,ending) {
  text=text.replace(/\r\n|\r/g,'\n').replace(/\n/g,{LF:'\n',CRLF:'\r\n',CR:'\r'}[ending]??'\n');
  if(encoding.startsWith('UTF-16')){const bytes=Buffer.from(text,'utf16le');if(encoding==='UTF-16 BE')bytes.swap16();return Buffer.concat([Buffer.from(encoding==='UTF-16 BE'?[254,255]:[255,254]),bytes]);}
  const bytes=Buffer.from(text,'utf8');return encoding==='UTF-8 BOM'?Buffer.concat([Buffer.from([239,187,191]),bytes]):bytes;
}
function fingerprint(file){return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');}
function atomicWrite(file,data) {
  const temp=path.join(path.dirname(file),'.'+path.basename(file)+'.'+crypto.randomUUID()+'.tmp');
  try {fs.writeFileSync(temp,data,{flag:'wx',mode:0o600}); if(fs.existsSync(file))fs.chmodSync(temp,fs.statSync(file).mode);fs.renameSync(temp,file);}
  finally {if(fs.existsSync(temp))fs.unlinkSync(temp);}
}
function newer(a,b){const parse=v=>/^v?\d+\.\d+\.\d+$/.test(v)?v.replace(/^v/,'').split('.').map(Number):null;const x=parse(a),y=parse(b);if(!x||!y)return false;for(let i=0;i<3;i++){if(x[i]!==y[i])return x[i]>y[i];}return false;}
function assetFor(platform,version){return platform==='win32'?`Notepad-Desktop-${version}-Windows-x64-Setup.exe`:`Notepad-Desktop-${version}-Linux-x64.AppImage`;}
module.exports={decode,encode,fingerprint,atomicWrite,newer,assetFor,MAX_BYTES};
