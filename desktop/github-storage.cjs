const fs=require('node:fs');const path=require('node:path');const {atomicWrite}=require('./core.cjs');
function credentialStore({safeStorage,directory,platform=process.platform}){
 const file=path.join(directory,'github-account.enc');
 const available=async()=>{
  if(platform==='linux')return safeStorage.isEncryptionAvailable()&&!['basic_text','unknown'].includes(safeStorage.getSelectedStorageBackend());
  return safeStorage.isAsyncEncryptionAvailable();
 };
 return {available,
  async read(){if(!fs.existsSync(file))return null;if(!await available())throw Error('storage');const bytes=fs.readFileSync(file);if(bytes.length>65536)throw Error('storage');const text=platform==='linux'?safeStorage.decryptString(bytes):(await safeStorage.decryptStringAsync(bytes)).result;return JSON.parse(text);},
  async write(value){if(!await available())throw Error('storage');const text=JSON.stringify(value),encrypted=platform==='linux'?safeStorage.encryptString(text):await safeStorage.encryptStringAsync(text);fs.mkdirSync(directory,{recursive:true});atomicWrite(file,encrypted);fs.chmodSync(file,0o600);},
  async remove(){fs.rmSync(file,{force:true});}
 };
}
module.exports={credentialStore};
