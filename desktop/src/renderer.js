import palettes from '../../Resources/Palettes.json';
import {translate,localizeDOM} from './locale.js';
import {EditorState,Compartment} from '@codemirror/state';
import {EditorView,keymap,lineNumbers,highlightActiveLine,drawSelection} from '@codemirror/view';
import {defaultKeymap,history,historyKeymap,indentWithTab,isolateHistory} from '@codemirror/commands';
import {syntaxHighlighting,defaultHighlightStyle,bracketMatching,indentOnInput} from '@codemirror/language';
import {searchKeymap,openSearchPanel,search,highlightSelectionMatches} from '@codemirror/search';
import {closeBrackets,closeBracketsKeymap} from '@codemirror/autocomplete';
import {markdown} from '@codemirror/lang-markdown';
import {html} from '@codemirror/lang-html';
import {javascript} from '@codemirror/lang-javascript';
import {python} from '@codemirror/lang-python';
import {json} from '@codemirror/lang-json';
import {css} from '@codemirror/lang-css';
import {sql,SQLDialect} from '@codemirror/lang-sql';
import {oneDark} from '@codemirror/theme-one-dark';
import {marked} from 'marked';
import DOMPurify from 'dompurify';
let locale='ru';
const tr=value=>translate(value,locale);
const $=id=>document.getElementById(id),api=window.notepad;
let tabs=[],selected,settings={sqlDialect:'auto',locale:'ru',theme:'system',autoUpdates:true,updateInterval:24},view,preview=false,timer,previewTimer,noticeTimer,version='',states=new Map(),busy=false;
const langSlot=new Compartment(),themeSlot=new Compartment();
const kafka=SQLDialect.define({keywords:'SELECT FROM WHERE GROUP BY HAVING AS JOIN LEFT RIGHT INNER OUTER ON AND OR NOT NULL TRUE FALSE CREATE STREAM TABLE WITH KAFKA_TOPIC VALUE_FORMAT KEY_FORMAT PARTITIONS REPLICAS EMIT CHANGES INSERT INTO VALUES SET PRINT TOPICS SHOW STREAMS TABLES DESCRIBE EXPLAIN TERMINATE DROP IF EXISTS WINDOW TUMBLING HOPPING SESSION SIZE ADVANCE GRACE PERIOD WITHIN KEY STRUCT ARRAY MAP LATEST_BY_OFFSET EARLIEST_BY_OFFSET COUNT SUM AVG MAX MIN',builtin:'ROWTIME ROWKEY'});
function lang(tab){if(tab.language!=='auto')return tab.language;const ext=tab.title.split('.').pop().toLowerCase();return ({md:'markdown',markdown:'markdown',html:'html',htm:'html',sql:'sql',psql:'sql',pgsql:'sql',mysql:'sql',ddl:'sql',dml:'sql',ksql:'kafka',ksqldb:'kafka',js:'javascript',jsx:'javascript',ts:'typescript',tsx:'typescript',py:'python',json:'json',css:'css',scss:'css'})[ext]||'text';}
function languageExtension(tab){switch(lang(tab)){case'markdown':return markdown();case'html':return html();case'sql':return sql();case'kafka':return sql({dialect:kafka});case'javascript':return javascript({jsx:true});case'typescript':return javascript({typescript:true,jsx:true});case'python':return python();case'json':return json();case'css':return css();default:return [];}}
function scheme(){return palettes.find(p=>p.id===settings.colorScheme);}
function renderSchemes(){const el=$('color-scheme');el.replaceChildren(...[{id:'studio',ru:'Studio',en:'Studio'},...palettes.filter(p=>p.dark===dark())].map(p=>{const o=document.createElement('option');o.value=p.id;o.textContent=locale==='en'?p.en:p.ru;return o;}));el.value=scheme()?.id||'studio';}
function dark(){return settings.theme==='dark'||(settings.theme==='system'&&matchMedia('(prefers-color-scheme:dark)').matches);}
function current(){return tabs.find(t=>t.id===selected);}
function dirty(t){return t.text!==t.savedText||t.encoding!==t.savedEncoding||t.ending!==t.savedEnding;}
function notice(message){$('notice').textContent=tr(message);$('notice').hidden=false;clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>$('notice').hidden=true,7000);}
window.addEventListener('error',e=>notice('Ошибка интерфейса: '+e.message));
window.addEventListener('unhandledrejection',e=>notice('Ошибка: '+(e.reason?.message||e.reason)));
async function call(name,...args){const result=await api[name](...args);if(!result.ok)throw Error(result.error);return result.value;}
function capture(){const t=current();if(t&&view){t.text=view.state.doc.toString();t.selection=view.state.selection.main.head;states.set(t.id,view.state);}}
function snapshot(){capture();return {tabs,selected,settings};}
async function flush(){clearTimeout(timer);try{await call('snapshot',snapshot());return true;}catch(e){notice('Не удалось сохранить сессию: '+e.message);return false;}}
function schedule(){clearTimeout(timer);timer=setTimeout(flush,600);}
function newTab(){if(tabs.length>=300){notice(locale==='en'?'The limit is 300 open tabs. Close a tab before opening another.':'Открыто 300 вкладок. Закройте одну перед открытием новой.');return;}capture();const t={id:crypto.randomUUID(),title:`${locale==='en'?'Untitled':'Без имени'} ${tabs.filter(t=>!t.path).length+1}`,path:null,text:'',savedText:'',encoding:'UTF-8',savedEncoding:'UTF-8',ending:'LF',savedEnding:'LF',language:'auto',selection:0};tabs.push(t);select(t.id);}
function renderTabs(){const fragment=document.createDocumentFragment();for(const t of tabs){const group=document.createElement('div');group.className='tab'+(t.id===selected?' active':'');const name=document.createElement('button');name.className='tab-name';name.textContent=(dirty(t)?'● ':'')+t.title;name.title=t.path||t.title;name.setAttribute('aria-pressed',t.id===selected?'true':'false');name.onclick=()=>select(t.id);const close=document.createElement('button');close.className='close';close.textContent='×';close.setAttribute('aria-label',tr('Закрыть')+' '+t.title);close.onclick=()=>closeTab(t.id);group.append(name,close);fragment.append(group);}const add=document.createElement('button');add.textContent='＋';add.setAttribute('aria-label',tr('Новая вкладка'));add.onclick=newTab;fragment.append(add);$('tabs').replaceChildren(fragment);document.title=(current()?.title||'Notepad')+' — Notepad Desktop';}
function select(id){capture();selected=id;const t=current();if(!t)return;view?.destroy();let state=states.get(id);if(!state)state=EditorState.create({doc:t.text,selection:{anchor:Math.min(t.selection||0,t.text.length)},extensions:[lineNumbers(),history(),drawSelection(),highlightActiveLine(),bracketMatching(),indentOnInput(),closeBrackets(),search({top:true}),highlightSelectionMatches(),syntaxHighlighting(defaultHighlightStyle,{fallback:true}),EditorView.lineWrapping,langSlot.of(languageExtension(t)),themeSlot.of(dark()?oneDark:[]),keymap.of([...defaultKeymap,...historyKeymap,...searchKeymap,...closeBracketsKeymap,indentWithTab]),EditorView.updateListener.of(update=>{if(update.docChanged){t.text=update.state.doc.toString();renderTabs();refreshPreview();schedule();}if(update.docChanged||update.selectionSet)status();})]});view=new EditorView({state,parent:$('editor')});view.dispatch({effects:[langSlot.reconfigure(languageExtension(t)),themeSlot.reconfigure(dark()?oneDark:[])]});view.focus();renderTabs();status();refreshPreview();schedule();$('tabs').querySelector('.active')?.scrollIntoView({block:'nearest',inline:'nearest'});}
function status(){const t=current();if(!t||!view)return;const sel=view.state.selection.main;const line=view.state.doc.lineAt(sel.head);$('status').textContent=locale==='en'?`Ln ${line.number}, Col ${sel.head-line.from+1} · ${view.state.doc.length} chars`:`Стр ${line.number}, стлб ${sel.head-line.from+1} · ${view.state.doc.length} симв.`;$('path').textContent=t.path||(locale==='en'?'New document · restored on next launch':'Новый документ · сессия восстанавливается при запуске');$('path').title=$('path').textContent;$('language').value=t.language;$('encoding').value=t.encoding;$('ending').value=t.ending;}
async function open(){if(busy)return;busy=true;try{await flush();const opened=await call('open');capture();for(const t of opened){if(!tabs.some(x=>x.id===t.id))tabs.push(t);}if(opened.length)select(opened.at(-1).id);}catch(e){notice(e.message);}finally{busy=false;}}
async function save(as=false){const t=current();if(!t||busy)return false;busy=true;try{capture();await call('snapshot',snapshot());const saved=await call('save',t,as);if(!saved)return false;Object.assign(t,saved);renderTabs();status();refreshPreview();await flush();return true;}catch(e){notice(e.message);return false;}finally{busy=false;}}
async function closeTab(id){const t=tabs.find(t=>t.id===id);if(!t)return;if(id===selected)capture();if(dirty(t)){let answer;try{answer=await call('confirmClose',t.title);}catch(e){notice(e.message);return;}if(answer===1)return;if(answer===0){select(id);if(!await save())return;}}const index=tabs.indexOf(t);tabs.splice(index,1);states.delete(id);if(!tabs.length){view?.destroy();view=null;selected=null;newTab();}else if(id===selected){view?.destroy();view=null;selected=null;select(tabs[Math.min(index,tabs.length-1)].id);}else renderTabs();await flush();}
const markdownCSS=`:root{color-scheme:${dark()?'dark':'light'};font:15px/1.7 system-ui}body{padding:24px;max-width:900px;margin:auto;overflow-wrap:break-word}h1,h2,h3{line-height:1.25;letter-spacing:-.02em}h1,h2{border-bottom:1px solid #8885;padding-bottom:.4em}pre{background:#8882;padding:16px;overflow:auto;border-radius:9px}code{font-family:ui-monospace,Consolas,monospace}blockquote{border-left:3px solid #c58950;padding-left:16px;margin-left:0}table{border-collapse:collapse}th,td{border:1px solid #8885;padding:8px 12px}img{max-width:100%}`;
function refreshPreview(){clearTimeout(previewTimer);if(!preview)return;previewTimer=setTimeout(()=>{const t=current();if(!t)return;let content;if(t.text.length>2_000_000)content='<p>Предпросмотр доступен до 2 МБ.</p>';else if(lang(t)==='markdown')content=marked.parse(t.text);else if(lang(t)==='html')content=t.text;else content='<h2>Предпросмотр Markdown и HTML</h2><p>Откройте файл или выберите язык внизу окна.</p>';const clean=DOMPurify.sanitize(content,{WHOLE_DOCUMENT:true,ADD_TAGS:['style'],FORBID_TAGS:['script','iframe','form','object','embed','base','meta'],FORBID_ATTR:['action','formaction','srcset','target','href']});const csp="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data:; form-action 'none'; base-uri 'none'";const css=markdownCSS.replace(/color-scheme:(dark|light)/,`color-scheme:${dark()?'dark':'light'}`);$('rendered').srcdoc=`<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="${csp}"><style>${lang(t)==='html'?'html{color-scheme:light dark}':css}</style></head><body>${clean}</body></html>`;},200);}
function togglePreview(){preview=!preview;$('preview-pane').hidden=!preview;$('divider').hidden=!preview;$('preview').setAttribute('aria-pressed',String(preview));refreshPreview();}
function applyTheme(){
if(scheme()&&scheme().dark!==dark())settings.colorScheme='studio';
renderSchemes();
const p=scheme(),style=document.body.style;
for(const key of ['--bg','--panel','--editor','--text','--muted','--border','--accent','--hover'])style.removeProperty(key);
if(p){const mix=(a,b,t)=>'#'+[1,3,5].map(i=>Math.round(parseInt(a.slice(i,i+2),16)*(1-t)+parseInt(b.slice(i,i+2),16)*t).toString(16).padStart(2,'0')).join(''),fg=p.dark?'#F4F4F5':'#202124';
for(const [k,v]of Object.entries({'--bg':mix(p.background,fg,.04),'--panel':mix(p.background,fg,.09),'--editor':p.background,'--text':fg,'--muted':mix(p.background,fg,.68),'--border':mix(p.background,fg,.22),'--accent':p.accent,'--hover':mix(p.background,p.accent,.22)}))style.setProperty(k,v);
}
document.body.classList.toggle('light',!dark());view?.dispatch({effects:themeSlot.reconfigure(dark()?oneDark:[])});refreshPreview();}
async function checkUpdate(manual=true){try{const result=await call('update',manual);if(manual&&result.current)notice('Установлена последняя доступная версия для вашей ОС.');}catch(e){if(manual)notice(e.message);}}

let formatting=false;
async function formatDocument(){
 const tab=current();if(!tab||formatting)return;
 const kind=lang(tab);if(!['json','sql'].includes(kind)){notice(locale==='en'?'Choose JSON or SQL syntax. Kafka / ksqlDB formatting is not supported yet.':'Выберите JSON или SQL внизу окна. Форматирование Kafka / ksqlDB пока не поддерживается.');return;}
 const original=view.state.doc.toString(),selection=view.state.selection.main,from=selection.empty?0:selection.from,to=selection.empty?original.length:selection.to,source=original.slice(from,to);
 const limit=kind==='sql'?50000:1000000;if(source.length>limit){notice(locale==='en'?'Formatting limit: JSON 1M characters, SQL 50K. Select a smaller fragment.':'Для форматирования: JSON до 1 млн символов, SQL до 50 тыс. Выделите меньший фрагмент.');return;}
 const ext=tab.title.split('.').pop().toLowerCase(),dialect=settings.sqlDialect&&settings.sqlDialect!=='auto'?settings.sqlDialect:['psql','pgsql'].includes(ext)?'postgresql':ext==='mysql'?'mysql':'sql';
 formatting=true;$('format').disabled=true;
 let worker;let timeout;
 const finish=()=>{worker?.terminate();clearTimeout(timeout);formatting=false;$('format').disabled=false;};
 try{worker=new Worker(new URL('format-worker.js',import.meta.url));
 timeout=setTimeout(()=>{finish();notice(locale==='en'?'Formatting took too long. Original text kept.':'Форматирование заняло слишком долго. Исходный текст сохранён.');},10000);
 worker.onerror=()=>{finish();notice(locale==='en'?'Could not load the formatter.':'Не удалось загрузить форматирование.');};
 worker.onmessage=event=>{finish();if(current()?.id!==tab.id||view.state.doc.toString()!==original)return;
  const result=event.data;
  if(!result.ok){notice(locale==='en'?'Cannot format this document. Check the syntax or SQL dialect in Settings. Original text kept.':'Не удалось отформатировать: проверьте синтаксис или диалект SQL в настройках. Исходный текст сохранён.');return;}
  if(result.text!==source)view.dispatch({changes:{from,to,insert:result.text},selection:{anchor:from},annotations:isolateHistory.of('full')});view.focus();
 };worker.postMessage({source,kind,dialect});
 }catch{finish();notice(locale==='en'?'Could not start formatting.':'Не удалось запустить форматирование.');}
}

const actions={format:formatDocument,settings:()=>$('settings-dialog').showModal(),new:newTab,open,save:()=>save(false),'save-as':()=>save(true),close:()=>current()&&closeTab(selected),find:()=>view&&openSearchPanel(view),preview:togglePreview,about:()=>{$('settings-dialog').close();$('about-dialog').showModal();},update:()=>checkUpdate(true),flush,reload:async()=>{const data=await call('load');capture();for(const t of data.session.tabs){if(!tabs.some(x=>x.id===t.id))tabs.push(t);}select(data.session.selected||selected);}};
for(const id of ['new','open','save','find','preview','about','format','settings'])$(id).onclick=actions[id];
api.onCommand(command=>actions[command]?.());
function listTabs(){const query=$('tab-filter').value.toLocaleLowerCase();const results=document.createDocumentFragment();for(const t of tabs){if(query&&!(t.path||t.title).toLocaleLowerCase().includes(query))continue;const b=document.createElement('button');b.textContent=(t.id===selected?'✓ ':'')+(dirty(t)?'● ':'')+t.title;b.title=t.path||t.title;b.onclick=()=>{select(t.id);$('tabs-dialog').close();};results.append(b);}$('tab-results').replaceChildren(results);$('tabs-title').textContent=tr('Все вкладки')+' · '+tabs.length;}
$('tab-list').onclick=()=>{listTabs();$('tabs-dialog').showModal();$('tab-filter').focus();};
$('tab-filter').oninput=listTabs;
$('close-tab-list').onclick=()=>$('tabs-dialog').close();
$('tabs').addEventListener('wheel',event=>{if(Math.abs(event.deltaY)>Math.abs(event.deltaX)&&$('tabs').scrollWidth>$('tabs').clientWidth){event.preventDefault();$('tabs').scrollLeft+=event.deltaY;}},{passive:false});
$('close-settings').onclick=()=>$('settings-dialog').close();
$('color-scheme').onchange=()=>{settings.colorScheme=$('color-scheme').value;applyTheme();schedule();};
$('sql-dialect').onchange=()=>{settings.sqlDialect=$('sql-dialect').value;schedule();};
$('dismiss').onclick=()=>$('about-dialog').close();
for(const id of ['profile','repo','roadmap','telegram'])$(id).onclick=()=>call('external',id).catch(e=>notice(e.message));
$('copy').onclick=()=>call('copyDonation').then(()=>notice('Номер скопирован')).catch(e=>notice(e.message));
$('check-update').onclick=()=>checkUpdate(true);
$('auto-update').onchange=()=>{settings.autoUpdates=$('auto-update').checked;schedule();};
$('update-interval').onchange=()=>{settings.updateInterval=Number($('update-interval').value);schedule();};
$('ui-language').onchange=()=>{locale=$('ui-language').value;settings.locale=locale;localizeDOM(locale);renderSchemes();renderTabs();status();schedule();};
$('theme').onchange=()=>{settings.theme=$('theme').value;applyTheme();schedule();};
for(const key of ['language','encoding','ending'])$(key).onchange=()=>{const t=current();if(!t)return;t[key]=$(key).value;if(key==='language')view.dispatch({effects:langSlot.reconfigure(languageExtension(t))});renderTabs();status();refreshPreview();schedule();};
matchMedia('(prefers-color-scheme:dark)').addEventListener('change',applyTheme);
window.addEventListener('online',()=>checkUpdate(false));
function splitAt(percent){percent=Math.min(75,Math.max(25,percent));$('preview-pane').style.width=percent+'%';$('divider').setAttribute('aria-valuenow',String(Math.round(percent)));}
$('divider').onpointerdown=event=>{$('divider').setPointerCapture(event.pointerId);$('divider').onpointermove=e=>{if(e.buttons!==1)return;const rect=$('workspace').getBoundingClientRect();splitAt(100*(rect.right-e.clientX)/rect.width);};};
$('divider').onkeydown=e=>{if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();splitAt(Number($('divider').getAttribute('aria-valuenow'))+(e.key==='ArrowLeft'?5:-5));}};
document.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey)&&e.shiftKey&&e.key.toLowerCase()==='f'){e.preventDefault();formatDocument();return;}if((e.ctrlKey||e.metaKey)&&e.shiftKey&&e.key.toLowerCase()==='a'){e.preventDefault();$('tab-list').click();return;}if((e.ctrlKey||e.metaKey)&&e.key==='Tab'){e.preventDefault();const index=tabs.findIndex(t=>t.id===selected);select(tabs[(index+(e.shiftKey?-1:1)+tabs.length)%tabs.length].id);}});
try{const data=await call('load');version=data.version;tabs=data.session.tabs||[];settings={...settings,...data.session.settings};locale=settings.locale==='en'?'en':'ru';localizeDOM(locale);renderSchemes();$('ui-language').value=locale;$('sql-dialect').value=settings.sqlDialect||'auto';selected=data.session.selected;$('version').textContent=version;$('theme').value=settings.theme;$('auto-update').checked=settings.autoUpdates;$('update-interval').value=String(settings.updateInterval);applyTheme();if(!tabs.length)newTab();else{selected=null;select(data.session.selected&&tabs.some(t=>t.id===data.session.selected)?data.session.selected:tabs[0].id);}setTimeout(()=>checkUpdate(false),3000);setInterval(()=>checkUpdate(false),600000);}catch(e){notice('Не удалось загрузить сессию: '+e.message);}
