const {app,BrowserWindow,Menu,dialog,ipcMain,shell,clipboard,session}=require('electron');
const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');
const {decode,encode,fingerprint,atomicWrite,newer,assetFor,MAX_BYTES}=require('./core.cjs');
const en=()=>model.settings?.locale==='en';
const tr=(ru,english)=>en()?english:ru;
const REPO='https://github.com/starscream001/notepad_for_mac';

const menuTranslations={'Файл':'File','Новая вкладка':'New Tab','Открыть':'Open','Сохранить':'Save','Сохранить как':'Save As','Закрыть вкладку':'Close Tab','Выход':'Quit','Правка':'Edit','Отменить':'Undo','Повторить':'Redo','Вырезать':'Cut','Копировать':'Copy','Вставить':'Paste','Выделить всё':'Select All','Найти / заменить':'Find / Replace','Вид':'View','Предпросмотр':'Preview','Помощь':'Help','О приложении / Поддержать':'About / Support','Проверить обновления':'Check for Updates','Дорожная карта':'Roadmap'};
let menuTemplate, menuLocale;
function refreshMenuLanguage(){const locale=en()?'en':'ru';if(!menuTemplate||menuLocale===locale)return;menuLocale=locale;const translateItems=items=>items.map(item=>({...item,label:locale==='en'?(menuTranslations[item.label]||item.label):item.label,submenu:Array.isArray(item.submenu)?translateItems(item.submenu):item.submenu}));Menu.setApplicationMenu(Menu.buildFromTemplate(translateItems(menuTemplate)));}


let win,model={tabs:[],selected:null,settings:{}},paths=new Map(),closing=false,allowClose=false,lastUpdate=0,checking=false;
if(process.env.NOTEPAD_DESKTOP_DATA)app.setPath('userData',path.resolve(process.env.NOTEPAD_DESKTOP_DATA));
const stateFile=()=>path.join(app.getPath('userData'),'session.json');
function persist(){fs.mkdirSync(path.dirname(stateFile()),{recursive:true});atomicWrite(stateFile(),JSON.stringify(model));}
function readFile(file){
  file=fs.realpathSync(file);if(fs.statSync(file).size>MAX_BYTES)throw Error('Поддерживаются файлы до 20 МБ.');
  const value=decode(fs.readFileSync(file));const tab={id:crypto.randomUUID(),path:file,title:path.basename(file),...value,savedText:value.text,savedEncoding:value.encoding,savedEnding:value.ending,diskHash:fingerprint(file),language:'auto',selection:0};
  const existing=model.tabs.find(t=>t.path===file);if(existing)return existing;
  paths.set(tab.id,file);model.tabs.push(tab);model.selected=tab.id;return tab;
}
function load(){
  if(!fs.existsSync(stateFile()))return;
  try {const saved=JSON.parse(fs.readFileSync(stateFile(),'utf8'));if(!Array.isArray(saved.tabs))throw Error('Неверная сессия');model=saved;
    for(const tab of model.tabs){if(tab.path){paths.set(tab.id,tab.path);if(tab.text===tab.savedText&&fs.existsSync(tab.path)){const current=decode(fs.readFileSync(tab.path));Object.assign(tab,current,{savedText:current.text,savedEncoding:current.encoding,savedEnding:current.ending,diskHash:fingerprint(tab.path)});}}}
  }catch(error){const backup=stateFile()+'.damaged-'+Date.now();fs.renameSync(stateFile(),backup);model={tabs:[],selected:null,settings:{}};dialog.showErrorBox('Сессия сохранена для восстановления',`${error.message}\nКопия: ${backup}`);}
}
function command(name){win?.webContents.send('command',name);}
function trusted(event){if(event.sender!==win?.webContents||event.senderFrame!==win.webContents.mainFrame)throw Error('Недопустимый отправитель');}
function handler(name,fn){ipcMain.handle(name,async(event,...args)=>{trusted(event);try{return {ok:true,value:await fn(...args)};}catch(error){const messages={'Бинарный файл не поддерживается.':'Binary files are not supported.','Поддерживаются файлы до 20 МБ.':'Files up to 20 MB are supported.','Файл уже открыт в другой вкладке.':'This file is already open in another tab.','Неверная кодировка.':'Invalid encoding.'};return {ok:false,error:en()?(messages[error.message]||error.message):error.message};}});}
handler('load',()=>({session:model,version:app.getVersion(),platform:process.platform}));
handler('open',async()=>{const result=await dialog.showOpenDialog(win,{properties:['openFile','multiSelections']});if(result.canceled)return [];const newPaths=[...new Set(result.filePaths.map(p=>fs.realpathSync(p)))].filter(p=>!model.tabs.some(t=>t.path===p));if(model.tabs.length+newPaths.length>300)throw Error(tr('Можно открыть не более 300 вкладок.','You can open up to 300 tabs.'));return result.filePaths.map(readFile);});
handler('save',async(tab,as)=>{
  if(typeof tab?.id!=='string'||typeof tab.text!=='string'||Buffer.byteLength(tab.text)>MAX_BYTES)throw Error('Некорректный документ или больше 20 МБ.');
  if(!['UTF-8','UTF-8 BOM','UTF-16 LE','UTF-16 BE'].includes(tab.encoding)||!['LF','CRLF','CR'].includes(tab.ending))throw Error('Неверная кодировка.');
  let file=paths.get(tab.id);const old=model.tabs.find(t=>t.id===tab.id);
  if(as||!file){const result=await dialog.showSaveDialog(win,{defaultPath:file||tab.title||'Untitled.txt'});if(result.canceled)return null;file=result.filePath;}
  if(fs.existsSync(file))file=fs.realpathSync(file);
  if([...paths].some(([id,p])=>id!==tab.id&&p===file))throw Error('Файл уже открыт в другой вкладке.');
  if(!as&&old?.diskHash&&fs.existsSync(file)&&fingerprint(file)!==old.diskHash){const r=await dialog.showMessageBox(win,{type:'warning',message:tr('Файл изменён другой программой','File changed outside the editor'),detail:'Перезаписать текущим текстом? Можно отменить и выбрать «Сохранить как».',buttons:[tr('Отмена','Cancel'),tr('Перезаписать','Overwrite')],defaultId:0,cancelId:0});if(r.response!==1)return null;}
  atomicWrite(file,encode(tab.text,tab.encoding,tab.ending));paths.set(tab.id,file);
  const saved={...tab,path:file,title:path.basename(file),savedText:tab.text,savedEncoding:tab.encoding,savedEnding:tab.ending,diskHash:fingerprint(file)};
  const i=model.tabs.findIndex(t=>t.id===tab.id);if(i>=0)model.tabs[i]=saved;else model.tabs.push(saved);persist();return saved;
});
handler('snapshot',value=>{
  if(!Array.isArray(value?.tabs)||value.tabs.length>300||value.tabs.some(t=>typeof t.id!=='string'||typeof t.text!=='string'||Buffer.byteLength(t.text)>MAX_BYTES))throw Error('Сессия слишком большая или повреждена.');
  model={tabs:value.tabs.map(t=>{const previous=model.tabs.find(x=>x.id===t.id);return {...t,path:paths.get(t.id)||null,diskHash:previous?.diskHash||null};}),selected:value.selected,settings:value.settings||{}};
  persist();refreshMenuLanguage();if(closing){allowClose=true;win.close();}return true;
});
handler('confirm-close',async title=>{const r=await dialog.showMessageBox(win,{type:'question',message:en()?`Save “${String(title).slice(0,200)}”?`:`Сохранить «${String(title).slice(0,200)}»?`,buttons:[tr('Сохранить','Save'),tr('Отмена','Cancel'),tr('Не сохранять',"Don't Save")],defaultId:0,cancelId:1});return r.response;});
handler('external',kind=>{const urls={telegram:'https://t.me/Ilya_Manik',profile:'https://github.com/starscream001',repo:REPO,releases:REPO+'/releases/latest',roadmap:REPO+'/blob/main/docs/ROADMAP.md'};if(urls[kind])return shell.openExternal(urls[kind]);});
handler('copy-donation',()=>{clipboard.writeText('+79632433100');return true;});
handler('update',async manual=>{
  if(checking)return {busy:true};const interval=Number(model.settings?.updateInterval)||24;
  if(!manual&&(model.settings?.autoUpdates===false||Date.now()-lastUpdate<interval*3600000))return {skipped:true};
  checking=true;
  try {const response=await fetch('https://api.github.com/repos/starscream001/notepad_for_mac/releases/latest',{headers:{'User-Agent':'Notepad-Desktop/'+app.getVersion(),'Accept':'application/vnd.github+json'},signal:AbortSignal.timeout(15000)});
    if(!response.ok)throw Error(`GitHub недоступен (HTTP ${response.status}). Повторите позже.`);const release=await response.json();lastUpdate=Date.now();
    if(!newer(release.tag_name,app.getVersion())||release.draft||release.prerelease)return {current:true};
    const version=release.tag_name.replace(/^v/,'');const asset=release.assets?.find(a=>a.name===assetFor(process.platform,version));
    if(!asset)return {current:true};
    const result=await dialog.showMessageBox(win,{type:'info',message:en()?`Version ${version} is available`:`Доступна версия ${version}`,detail:'Откроется страница GitHub с файлами для вашей ОС. Сохраните работу, завершите приложение и установите новую версию. Автоматическая замена Windows/Linux запланирована следующим этапом.',buttons:[tr('Открыть релиз','Open Release'),tr('Позже','Later')],defaultId:0,cancelId:1});
    if(result.response===0)await shell.openExternal(REPO+'/releases/tag/v'+version);return {available:version};
  }finally{checking=false;}
});
if(!app.requestSingleInstanceLock())app.quit();
else {
 app.on('second-instance',(_event,argv)=>{if(win){win.show();win.focus();for(const arg of argv.slice(1)){if(!arg.startsWith('-')&&fs.existsSync(arg)&&fs.statSync(arg).isFile()){try{readFile(arg);command('reload');}catch(error){dialog.showErrorBox('Не удалось открыть',error.message);}}}}});
 app.whenReady().then(()=>{
  load();
  const args = app.isPackaged ? process.argv.slice(1) : process.argv.slice(2);
  for(const file of args) { if(!file.startsWith('-') && fs.existsSync(file) && fs.statSync(file).isFile()) { try { readFile(file); } catch(error) { dialog.showErrorBox('Не удалось открыть',error.message); } } }
  const menu=[{label:'Файл',submenu:[{label:'Новая вкладка',accelerator:'CmdOrCtrl+N',click:()=>command('new')},{label:'Открыть',accelerator:'CmdOrCtrl+O',click:()=>command('open')},{label:'Сохранить',accelerator:'CmdOrCtrl+S',click:()=>command('save')},{label:'Сохранить как',accelerator:'CmdOrCtrl+Shift+S',click:()=>command('save-as')},{label:'Закрыть вкладку',accelerator:'CmdOrCtrl+W',click:()=>command('close')},{type:'separator'},{role:'quit',label:'Выход'}]},
   {label:'Правка',submenu:[{role:'undo',label:'Отменить'},{role:'redo',label:'Повторить'},{type:'separator'},{role:'cut',label:'Вырезать'},{role:'copy',label:'Копировать'},{role:'paste',label:'Вставить'},{role:'selectAll',label:'Выделить всё'},{label:'Найти / заменить',accelerator:'CmdOrCtrl+F',click:()=>command('find')}]},
   {label:'Вид',submenu:[{label:'Предпросмотр',accelerator:'CmdOrCtrl+Alt+P',click:()=>command('preview')},{role:'zoomIn'},{role:'zoomOut'},{role:'resetZoom'},{role:'togglefullscreen'}]},
   {label:'Помощь',submenu:[{label:'О приложении / Поддержать',click:()=>command('about')},{label:'Проверить обновления',click:()=>command('update')},{label:'Дорожная карта',click:()=>shell.openExternal(REPO+'/blob/main/docs/ROADMAP.md')}]}
  ];if(process.platform==='darwin')menu.unshift({label:app.name,submenu:[{role:'about'},{role:'quit'}]});menuTemplate=menu;refreshMenuLanguage();
  win=new BrowserWindow({width:1180,height:800,minWidth:800,minHeight:480,backgroundColor:'#18192b',icon:path.join(__dirname,'assets/icon.png'),webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,webviewTag:false}});
  session.defaultSession.setPermissionRequestHandler((_web,_permission,callback)=>callback(false));
  win.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  win.webContents.on('will-navigate',event=>event.preventDefault());
  win.webContents.on('console-message', (_event, details) => {
    if (details.level === 'error' || details.level === 3) {
      try { fs.appendFileSync(path.join(app.getPath('userData'),'errors.log'), new Date().toISOString()+' '+details.message+'\n'); } catch {}
    }
  });
  win.loadFile('ui/index.html');
  win.on('close',event=>{if(allowClose)return;event.preventDefault();if(closing)return;closing=true;command('flush');setTimeout(()=>{if(!allowClose&&win&&!win.isDestroyed()){closing=false;dialog.showErrorBox('Сессия не сохранена','Не удалось подтвердить сохранение. Сохраните важные документы и повторите выход.');}},5000);});
 });
 app.on('window-all-closed',()=>app.quit());
}
