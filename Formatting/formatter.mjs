import {formatDialect, sql, postgresql, mysql} from 'sql-formatter';

// Keep JSON lexemes verbatim: JSON.stringify would round large numbers and drop duplicate keys.
export function prettyJSON(source) {
  try { JSON.parse(source); } catch { throw new Error('invalid-json'); }
  let result='', depth=0, quoted=false, escaped=false;
  const indent=()=> '  '.repeat(depth);
  for(let i=0;i<source.length;i++) {
    if(result.length>2_000_000)throw new Error('too-large');
    const c=source[i];
    if(quoted){result+=c;if(escaped)escaped=false;else if(c==='\\')escaped=true;else if(c==='"')quoted=false;continue;}
    if(/\s/.test(c))continue;
    if(c==='"'){quoted=true;result+=c;}
    else if(c==='{'||c==='['){result+=c;if(++depth>64)throw new Error('too-deep');let j=i+1;while(/\s/.test(source[j]||'')&&j<source.length)j++;if(source[j]!=='}'&&source[j]!==']')result+='\n'+indent();}
    else if(c==='}'||c===']'){depth--;const prev=result.at(-1);if(prev!=='{'&&prev!=='[')result+='\n'+indent();result+=c;}
    else if(c===',')result+=',\n'+indent();
    else if(c===':')result+=': ';
    else result+=c;
  }
  return result;
}
export function formatText(source,kind,dialect='sql') {
  if(source.length> (kind==='sql'?50_000:1_000_000))throw new Error('too-large');
  if(!source.trim())return source;
  const newline=source.endsWith('\n')?'\n':'';
  if(kind==='json')return prettyJSON(source)+newline;
  if(kind==='sql'){
    const grammar={sql,postgresql,mysql}[dialect];if(!grammar)throw new Error('unsupported-dialect');
    try{return formatDialect(source,{dialect:grammar,tabWidth:2,keywordCase:'preserve',linesBetweenQueries:1}).trimEnd()+newline;}
    catch{throw new Error('invalid-sql');}
  }
  throw new Error('unsupported-format');
}
export function run(source,kind,dialect){try{return {ok:true,text:formatText(source,kind,dialect)};}catch(e){return {ok:false,error:e.message};}}
