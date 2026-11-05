const {app,BrowserWindow,Menu,dialog,ipcMain,shell,clipboard,session,safeStorage}=require('electron');
const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');
const {decode,encode,fingerprint,atomicWrite,newer,assetFor,MAX_BYTES}=require('./core.cjs');
const updates=require('./updates.cjs');
const projectsCore=require('./projects.cjs');
const {GitHubAuth}=require('./github-auth.cjs');
const {credentialStore}=require('./github-storage.cjs');
let githubAuth;
const githubAccount=()=>{if(!githubAuth){const config=require('./github-oauth.json');githubAuth=new GitHubAuth({clientID:process.env.NOTEPAD_GITHUB_CLIENT_ID||config.clientID,storage:credentialStore({safeStorage,directory:app.getPath('userData')}),openBrowser:url=>shell.openExternal(url),emit:state=>{if(win&&!win.isDestroyed())win.webContents.send('github-account-state',state);}});}return githubAuth;};
let updateController=null,preparedUpdate=null,installingUpdate=false;
const updateState=value=>{if(win&&!win.isDestroyed())win.webContents.send('update-state',value);};
const en=()=>model.settings?.locale==='en';
const tr=(ru,english)=>en()?english:ru;
const REPO='https://github.com/starscream001/notepad_for_mac';

const menuTranslations={'Форматировать':'Format Document / Selection','Настройки':'Settings','Файл':'File','Новая вкладка':'New Tab','Открыть':'Open','Сохранить':'Save','Сохранить как':'Save As','Закрыть вкладку':'Close Tab','Выход':'Quit','Правка':'Edit','Отменить':'Undo','Повторить':'Redo','Вырезать':'Cut','Копировать':'Copy','Вставить':'Paste','Выделить всё':'Select All','Найти / заменить':'Find / Replace','Вид':'View','Предпросмотр':'Preview','Помощь':'Help','О приложении / Поддержать':'About / Support','Проверить обновления':'Check for Updates','Дорожная карта':'Roadmap'};
let menuTemplate, menuLocale;
function refreshMenuLanguage(){const locale=en()?'en':'ru';if(!menuTemplate||menuLocale===locale)return;menuLocale=locale;const translateItems=items=>items.map(item=>({...item,label:locale==='en'?(menuTranslations[item.label]||item.label):item.label,submenu:Array.isArray(item.submenu)?translateItems(item.submenu):item.submenu}));Menu.setApplicationMenu(Menu.buildFromTemplate(translateItems(menuTemplate)));}


let win,model={tabs:[],selected:null,settings:{}},paths=new Map(),closing=false,allowClose=false,lastUpdate=0,checking=false;
if(process.env.NOTEPAD_DESKTOP_DATA)app.setPath('userData',path.resolve(process.env.NOTEPAD_DESKTOP_DATA));
const stateFile=()=>path.join(app.getPath('userData'),'session.json');
function persist(){fs.mkdirSync(path.dirname(stateFile()),{recursive:true});atomicWrite(stateFile(),JSON.stringify(model));}
function readFile(file){
  file=fs.realpathSync(file);if(fs.statSync(file).size>MAX_BYTES)throw Error('Поддерживаются файлы до 20 МБ.');
  const value=decode(fs.readFileSync(file));const tab={id:crypto.randomUUID(),path:file,title:path.basename(file),...value,savedText:value.text,savedEncoding:value.encoding,savedEnding:value.ending,diskHash:fingerprint(file),language:'auto',selection:0,projectId:model.selectedProject||null};
  const existing=model.tabs.find(t=>t.path===file);if(existing)return existing;
  const archived=(model.archivedTabs||[]).find(t=>t.path===file);if(archived){model.archivedTabs=model.archivedTabs.filter(t=>t.id!==archived.id);model.tabs.push(archived);model.selected=archived.id;return archived;}
  paths.set(tab.id,file);model.tabs.push(tab);model.selected=tab.id;return tab;
}
function load(){
  if(!fs.existsSync(stateFile()))return;
  try {const saved=JSON.parse(fs.readFileSync(stateFile(),'utf8'));if(!Array.isArray(saved.tabs))throw Error('Неверная сессия');if(!Array.isArray(saved.projects)){try{fs.copyFileSync(stateFile(),path.join(path.dirname(stateFile()),'session.before-projects.json'),fs.constants.COPYFILE_EXCL);}catch(e){if(e.code!=='EEXIST')throw e;}}model=projectsCore.normalize(saved);
    for(const tab of [...model.tabs,...(model.archivedTabs||[])]){if(tab.path){paths.set(tab.id,tab.path);if(tab.text===tab.savedText&&fs.existsSync(tab.path)){const current=decode(fs.readFileSync(tab.path));Object.assign(tab,current,{savedText:current.text,savedEncoding:current.encoding,savedEnding:current.ending,diskHash:fingerprint(tab.path)});}}}
  }catch(error){const backup=stateFile()+'.damaged-'+Date.now();fs.renameSync(stateFile(),backup);model={tabs:[],selected:null,settings:{}};dialog.showErrorBox('Сессия сохранена для восстановления',`${error.message}\nКопия: ${backup}`);}
}
function command(name){win?.webContents.send('command',name);}
function trusted(event){if(event.sender!==win?.webContents||event.senderFrame!==win.webContents.mainFrame)throw Error('Недопустимый отправитель');}
function handler(name,fn){ipcMain.handle(name,async(event,...args)=>{trusted(event);try{return {ok:true,value:await fn(...args)};}catch(error){const messages={'Бинарный файл не поддерживается.':'Binary files are not supported.','Поддерживаются файлы до 20 МБ.':'Files up to 20 MB are supported.','Файл уже открыт в другой вкладке.':'This file is already open in another tab.','Неверная кодировка.':'Invalid encoding.'};return {ok:false,error:en()?(messages[error.message]||error.message):error.message};}});}
const syncCore=()=>require('./sync-core.cjs');
function portable(model){return syncCore().clean({schema:1,projects:(model.projects||[]).map(p=>({id:p.id,title:p.title})),deleted:model.settings?.deletedNoteIds||[],tabs:[...model.tabs,...(model.archivedTabs||[])].map(t=>({id:t.id,projectId:t.projectId||null,title:t.title,text:t.text}))});}
handler('github-sync',async repo=>{
 if(typeof repo!=='string'||!/^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$/.test(repo))throw Error('invalid_repository');
 const account=githubAccount(),state=await account.status();if(!state.profile)throw Error('unauthorized');
 const confirmed=await dialog.showMessageBox(win,{type:'question',message:tr('Синхронизировать заметки с GitHub?','Synchronize notes with GitHub?'),detail:`${state.profile.login}/${repo}\n`+tr('Все открытые проекты и вкладки будут отправлены в этот приватный репозиторий; удалённые заметки будут загружены. При конфликте сохранятся обе версии. Закрытие вкладки не удаляет заметку из облака.','All open projects and tabs will be uploaded to this private repository; remote notes will be downloaded. Conflicts keep both versions. Closing a tab does not delete its cloud copy.'),buttons:[tr('Отмена','Cancel'),tr('Синхронизировать','Synchronize')],defaultId:0,cancelId:0});if(confirmed.response!==1)return null;
 const cacheFile=path.join(app.getPath('userData'),'github-sync.json'),key=state.profile.id+'/'+repo;
 let cache={};if(fs.existsSync(cacheFile)){try{cache=JSON.parse(fs.readFileSync(cacheFile,'utf8'));}catch{throw Error('sync_cache_damaged');}}
 const initial=portable(model),result=await account.synchronize({repo,base:cache[key]?.base||null,local:initial});
 const applied=syncCore().merge(initial,portable(model),result.snapshot,Array.from({length:300},()=>crypto.randomUUID()));
 const previous=model;atomicWrite(path.join(app.getPath('userData'),'session.before-sync.json'),JSON.stringify(previous));
 const openIDs=new Set(model.tabs.map(t=>t.id.toLowerCase()));
 const existing=new Map([...model.tabs,...(model.archivedTabs||[])].map(t=>[t.id.toLowerCase(),t])),existingProjects=new Map((model.projects||[]).map(p=>[p.id.toLowerCase(),p]));
 const nextTabs=applied.snapshot.tabs.map(t=>({...existing.get(t.id),...t,path:existing.get(t.id)?.path||null,savedText:existing.get(t.id)?.savedText||'',encoding:existing.get(t.id)?.encoding||'UTF-8',savedEncoding:existing.get(t.id)?.savedEncoding||'UTF-8',ending:existing.get(t.id)?.ending||'LF',savedEnding:existing.get(t.id)?.savedEnding||'LF',language:existing.get(t.id)?.language||'auto',selection:existing.get(t.id)?.selection||0}));
 model={...model,tabs:nextTabs.filter(t=>openIDs.has(t.id)||!existing.has(t.id)),archivedTabs:nextTabs.filter(t=>!openIDs.has(t.id)&&existing.has(t.id)),settings:{...model.settings,deletedNoteIds:applied.snapshot.deleted},projects:applied.snapshot.projects.map(p=>({...existingProjects.get(p.id),...p})),selected:model.selected?.toLowerCase()||null,selectedProject:model.selectedProject?.toLowerCase()||null};
 // Normalize trusted path map to canonical IDs; downloaded tabs never acquire local paths.
 const priorPaths=new Map(paths);paths=new Map([...paths].map(([id,p])=>[id.toLowerCase(),p]));
 try{persist();}catch(e){model=previous;paths=priorPaths;throw e;}
 cache[key]={base:result.snapshot,head:result.head,lastSync:new Date().toISOString()};atomicWrite(cacheFile,JSON.stringify(cache));
 return {session:model,conflicts:result.conflicts+applied.conflicts,pending:syncCore().stringify(applied.snapshot)!==syncCore().stringify(result.snapshot)};
});
handler('github-create-repository',async name=>{
 if(typeof name!=='string'||!/^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$/.test(name))throw Error('invalid_name');
 const state=await githubAccount().status();if(!state.profile)throw Error('unauthorized');
 const result=await dialog.showMessageBox(win,{type:'question',title:tr('Приватный репозиторий','Private repository'),message:tr('Создать приватный репозиторий?','Create a private repository?'),detail:`${state.profile.login}/${name}\n`+tr('Сейчас создаётся только пустое хранилище с README. Заметки не отправляются.','Only an empty repository with a README is created. Notes are not uploaded.'),buttons:[tr('Отмена','Cancel'),tr('Создать','Create')],defaultId:0,cancelId:0});
 if(result.response!==1)return null;return githubAccount().createRepository(name,true);
});
handler('github-install-app',()=>shell.openExternal('https://github.com/apps/notepad-desktop/installations/new'));
handler('github-status',()=>githubAccount().status());
handler('github-start',()=>githubAccount().start());
handler('github-cancel',()=>githubAccount().cancel());
handler('github-disconnect',()=>githubAccount().disconnect());
handler('github-refresh',()=>githubAccount().refresh());
handler('github-browser',()=>{if(githubAccount().state.phase==='waiting')return shell.openExternal('https://github.com/login/device');});
handler('github-copy-code',()=>{const state=githubAccount().state;if(state.phase==='waiting')clipboard.writeText(state.userCode);});
handler('github-profile',()=>{const state=githubAccount().state;if(state.profile)return shell.openExternal(state.profile.url);});
handler('load',()=>({session:model,version:app.getVersion(),platform:process.platform}));
handler('open',async()=>{const result=await dialog.showOpenDialog(win,{properties:['openFile','multiSelections']});if(result.canceled)return [];const newPaths=[...new Set(result.filePaths.map(p=>fs.realpathSync(p)))].filter(p=>!model.tabs.some(t=>t.path===p));if(model.tabs.length+newPaths.length>300)throw Error(tr('Можно открыть не более 300 вкладок.','You can open up to 300 tabs.'));return result.filePaths.map(readFile);});
handler('save',async(tab,as)=>{
  if(typeof tab?.id!=='string'||typeof tab.text!=='string'||Buffer.byteLength(tab.text)>MAX_BYTES)throw Error('Некорректный документ или больше 20 МБ.');
  if(!['UTF-8','UTF-8 BOM','UTF-16 LE','UTF-16 BE'].includes(tab.encoding)||!['LF','CRLF','CR'].includes(tab.ending))throw Error('Неверная кодировка.');
  let file=paths.get(tab.id);const old=model.tabs.find(t=>t.id===tab.id);
  if(as||!file){const result=await dialog.showSaveDialog(win,{defaultPath:file||(projectsCore.title(tab,model.projects||[])+'.txt')});if(result.canceled)return null;file=result.filePath;}
  if(fs.existsSync(file))file=fs.realpathSync(file);
  if([...paths].some(([id,p])=>id!==tab.id&&p===file))throw Error('Файл уже открыт в другой вкладке.');
  if(!as&&old?.diskHash&&fs.existsSync(file)&&fingerprint(file)!==old.diskHash){const r=await dialog.showMessageBox(win,{type:'warning',message:tr('Файл изменён другой программой','File changed outside the editor'),detail:'Перезаписать текущим текстом? Можно отменить и выбрать «Сохранить как».',buttons:[tr('Отмена','Cancel'),tr('Перезаписать','Overwrite')],defaultId:0,cancelId:0});if(r.response!==1)return null;}
  atomicWrite(file,encode(tab.text,tab.encoding,tab.ending));paths.set(tab.id,file);
  const saved={...tab,path:file,title:tab.projectId?tab.title:path.basename(file),savedText:tab.text,savedEncoding:tab.encoding,savedEnding:tab.ending,diskHash:fingerprint(file)};
  const i=model.tabs.findIndex(t=>t.id===tab.id);if(i>=0)model.tabs[i]=saved;else model.tabs.push(saved);persist();return saved;
});
handler('snapshot',value=>{
  if(!Array.isArray(value?.tabs)||value.tabs.length>300||value.tabs.some(t=>typeof t.id!=='string'||typeof t.text!=='string'||Buffer.byteLength(t.text)>MAX_BYTES))throw Error('Сессия слишком большая или повреждена.');
  if(value.archivedTabs!==undefined&&(!Array.isArray(value.archivedTabs)||value.archivedTabs.length>300||value.archivedTabs.some(t=>typeof t.id!=='string'||typeof t.text!=='string'||Buffer.byteLength(t.text)>MAX_BYTES)))throw Error('Invalid archive');
  const normalized=projectsCore.normalize(value);
  model={archivedTabs:value.archivedTabs||[],tabs:normalized.tabs.map(t=>{const previous=model.tabs.find(x=>x.id===t.id);return {...t,path:paths.get(t.id)||null,diskHash:previous?.diskHash||null};}),selected:value.selected,settings:value.settings||{},projects:normalized.projects,selectedProject:normalized.selectedProject};
  persist();refreshMenuLanguage();if(closing){allowClose=true;win.close();}return true;
});
handler('confirm-delete',async title=>{const r=await dialog.showMessageBox(win,{type:'warning',message:tr('Удалить заметку?','Delete note?'),detail:String(title).slice(0,200)+'\n'+tr('Заметка удалится локально, а после синхронизации — из GitHub. Внешний файл на диске не удаляется.','The note will be deleted locally and, after synchronization, from GitHub. An external file on disk is kept.'),buttons:[tr('Отмена','Cancel'),tr('Удалить','Delete')],defaultId:0,cancelId:0});return r.response===1;});
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
    if(process.platform==='win32'){
      const item=updates.candidate(release,app.getVersion());
      if(preparedUpdate?.item.version===version){await updates.verified(preparedUpdate.file,preparedUpdate.item);updateState({phase:'ready',version});return {ready:version};}
      const result=await dialog.showMessageBox(win,{type:'info',message:en()?`Version ${version} is available`:`Доступна версия ${version}`,detail:tr('Скачать установщик внутри приложения? После проверки SHA256 можно установить обновление. Вкладки сохранятся перед выходом.','Download the installer inside the app? After SHA256 verification you can install the update. Tabs are preserved before quitting.'),buttons:[tr('Скачать обновление','Download Update'),tr('Позже','Later')],defaultId:0,cancelId:1});
      if(result.response!==0)return {available:version};
      updateController=new AbortController();const timeout=setTimeout(()=>updateController?.abort(new Error("Update download timed out.")),10*60*1000);
      updateState({phase:'downloading',version,received:0,total:item.size});let lastProgress=0;
      try{
        const file=await updates.download(item,path.join(app.getPath('userData'),'Updates'),{signal:updateController.signal,onProgress:(received,total)=>{if(Date.now()-lastProgress>100||received===total){lastProgress=Date.now();updateState({phase:'downloading',version,received,total});}}});
        // Preserve Windows Internet-zone checks for an executable downloaded outside a browser.
        try{await fs.promises.writeFile(file+':Zone.Identifier','[ZoneTransfer]\r\nZoneId=3\r\nHostUrl='+item.url+'\r\n');}
        catch(error){await fs.promises.rm(path.dirname(file),{recursive:true,force:true});throw error;}
        preparedUpdate={item,file};updateState({phase:'ready',version});return {ready:version};
      }catch(error){if(updateController.signal.aborted&&updateController.signal.reason?.name==='AbortError'){updateState({phase:'cancelled'});return {cancelled:true};}updateState({phase:'error',message:error.message});throw error;}
      finally{clearTimeout(timeout);updateController=null;}
    }
    const result=await dialog.showMessageBox(win,{type:'info',message:en()?`Version ${version} is available`:`Доступна версия ${version}`,detail:tr('Для Linux пока используется установка со страницы релиза.','Linux still uses installation from the release page.'),buttons:[tr('Открыть релиз','Open Release'),tr('Позже','Later')],defaultId:0,cancelId:1});
    if(result.response===0)await shell.openExternal(REPO+'/releases/tag/v'+version);return {available:version};
  }finally{checking=false;}
});
handler('cancel-update',()=>{updateController?.abort();return true;});
handler('install-update',async()=>{
  if(process.platform!=='win32'||!app.isPackaged||!preparedUpdate||updateController||installingUpdate)throw Error('No verified update is ready to install.');
  installingUpdate=true;
  try{
    // Renderer flush must succeed before this handler; persist again before launch.
    await updates.install(preparedUpdate,{save:persist,open:file=>shell.openPath(file),quit:()=>{allowClose=true;app.quit();}});
    return true;
  }finally{installingUpdate=false;}
});
app.on('before-quit',()=>{updateController?.abort();githubAuth?.cancel();});
if(!app.requestSingleInstanceLock())app.quit();
else {
 app.on('second-instance',(_event,argv)=>{if(win){win.show();win.focus();for(const arg of argv.slice(1)){if(!arg.startsWith('-')&&fs.existsSync(arg)&&fs.statSync(arg).isFile()){try{readFile(arg);command('reload');}catch(error){dialog.showErrorBox('Не удалось открыть',error.message);}}}}});
 app.whenReady().then(()=>{
  load();
  const args = app.isPackaged ? process.argv.slice(1) : process.argv.slice(2);
  for(const file of args) { if(!file.startsWith('-') && fs.existsSync(file) && fs.statSync(file).isFile()) { try { readFile(file); } catch(error) { dialog.showErrorBox('Не удалось открыть',error.message); } } }
  const menu=[{label:'Файл',submenu:[{label:'Новая вкладка',accelerator:'CmdOrCtrl+N',click:()=>command('new')},{label:'Открыть',accelerator:'CmdOrCtrl+O',click:()=>command('open')},{label:'Сохранить',accelerator:'CmdOrCtrl+S',click:()=>command('save')},{label:'Сохранить как',accelerator:'CmdOrCtrl+Shift+S',click:()=>command('save-as')},{label:'Закрыть вкладку',accelerator:'CmdOrCtrl+W',click:()=>command('close')},{type:'separator'},{role:'quit',label:'Выход'}]},
   {label:'Правка',submenu:[{role:'undo',label:'Отменить'},{role:'redo',label:'Повторить'},{type:'separator'},{role:'cut',label:'Вырезать'},{role:'copy',label:'Копировать'},{role:'paste',label:'Вставить'},{role:'selectAll',label:'Выделить всё'},{label:'Форматировать',accelerator:'CmdOrCtrl+Shift+F',click:()=>command('format')},{label:'Настройки',accelerator:'CmdOrCtrl+,',click:()=>command('settings')},{label:'Найти / заменить',accelerator:'CmdOrCtrl+F',click:()=>command('find')}]},
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
