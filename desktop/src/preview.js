// Preserve the document's html/head/body attributes instead of nesting a complete
// document in a second body. HTML keeps its own CSS and defaults to browser white.
export function previewDocument(source,kind,dark,marked,purify){
 const policy="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data:; script-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'";
 const markdownCSS=`:root{color-scheme:${dark?'dark':'light'};font:15px/1.7 system-ui}body{padding:24px;max-width:900px;margin:auto;overflow-wrap:break-word}h1,h2,h3{line-height:1.25}pre{background:#8882;padding:16px;overflow:auto;border-radius:8px}code{font-family:ui-monospace,Consolas,monospace}blockquote{border-left:3px solid #8886;padding-left:16px;margin-left:0}table{border-collapse:collapse}th,td{border:1px solid #8885;padding:8px 12px}img{max-width:100%}`;
 const input=source.length>2_000_000?'<p>Preview limit: 2 MB</p>':kind==='markdown'?marked.parse(source):kind==='html'?source:'<h2>Markdown / HTML</h2>';
 const root=purify.sanitize(input,{WHOLE_DOCUMENT:true,RETURN_DOM:true,ADD_TAGS:['style'],FORBID_TAGS:['script','iframe','object','embed','base','meta','link'],FORBID_ATTR:['action','formaction','srcset','target']});
 // Keep safe internal anchors; external browsing and resource loads are not preview features.
 for(const element of root.querySelectorAll('[href]'))if(!element.getAttribute('href').startsWith('#'))element.removeAttribute('href');
 const doc=root.ownerDocument,head=root.querySelector('head');
 const csp=doc.createElement('meta');csp.httpEquiv='Content-Security-Policy';csp.content=policy;head.prepend(csp);
 const encoding=doc.createElement('meta');encoding.setAttribute('charset','utf-8');head.prepend(encoding);
 const viewport=doc.createElement('meta');viewport.name='viewport';viewport.content='width=device-width,initial-scale=1';head.append(viewport);
 if(kind==='markdown'){const style=doc.createElement('style');style.textContent=markdownCSS;head.append(style);}
 return '<!doctype html>'+root.outerHTML;
}
