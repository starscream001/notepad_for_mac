import AppKit
import WebKit
import JavaScriptCore

/// Markdown parsing runs in a separate JS context with no file or network bridge.
/// The document itself is displayed by WebKit with scripts disabled.
final class PreviewPane: NSObject, WKNavigationDelegate {
    let view = NSView()
    let web: WKWebView
    private let parser = JSContext()!
    private var pending: DispatchWorkItem?
    private var revision = 0

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        web = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        web.navigationDelegate = self
        web.setAccessibilityLabel("Предпросмотр документа")
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.topAnchor.constraint(equalTo: view.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        if let url = Bundle.main.url(forResource: "marked", withExtension: "js"),
           let script = try? String(contentsOf: url, encoding: .utf8) {
            parser.evaluateScript(script)
            parser.evaluateScript("function renderMarkdown(source) { return marked.parse(source, {gfm:true}); }")
        }
    }

    func update(_ tab: EditorTab?, visible: Bool) {
        pending?.cancel()
        guard visible, let tab else { return }
        revision += 1
        let token = revision
        let work = DispatchWorkItem { [weak self, weak tab] in
            guard let self, let tab, token == self.revision else { return }
            self.render(tab)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func render(_ tab: EditorTab) {
        let source = tab.textView.string
        guard source.utf8.count <= 2_000_000 else {
            show("<p>Предпросмотр доступен для документов до 2 МБ. Редактирование остаётся доступным.</p>")
            return
        }
        let ext = tab.url?.pathExtension.lowercased() ?? ""
        let markdown = tab.language == "Markdown"
        let html = ["html", "htm"].contains(ext) || (tab.snapshot.syntaxLanguage == "HTML / XML")
        guard markdown || html else {
            show("<h2>Предпросмотр</h2><p>Откройте Markdown или HTML. Для новой вкладки выберите язык Markdown или HTML / XML внизу окна.</p>")
            return
        }
        let body: String
        if markdown {
            guard let result = parser.objectForKeyedSubscript("renderMarkdown")?.call(withArguments: [source]), !result.isUndefined else {
                show("<p>Не удалось загрузить модуль Markdown.</p>"); return
            }
            body = result.toString()
        } else { body = source }
        // No remote requests, forms, scripts, frames or local file access from a preview.
        // Inline CSS and embedded data images remain available for HTML mockups.
        let policy = "default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data:; script-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'"
        let css = markdown ? Self.markdownCSS : "html { color-scheme: light dark; } body { overflow-wrap:break-word; }"
        web.loadHTMLString("<!doctype html><html><head><meta charset='utf-8'><meta http-equiv='Content-Security-Policy' content=\"\(policy)\"><meta name='viewport' content='width=device-width,initial-scale=1'><style>\(css)</style></head><body>\(body)</body></html>", baseURL: nil)
    }

    private func show(_ body: String) {
        web.loadHTMLString("<html><head><meta charset='utf-8'><style>\(Self.markdownCSS)</style></head><body>\(body)</body></html>", baseURL: nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated {
            if let url = action.request.url, ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        } else if action.request.url?.scheme == "about" { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }

    static let markdownCSS = """
    :root { color-scheme:light dark; font:15px/1.65 -apple-system,BlinkMacSystemFont,sans-serif; }
    body { margin:0 auto; padding:28px; max-width:860px; overflow-wrap:break-word; }
    h1,h2,h3 { line-height:1.25; letter-spacing:-.02em; } h1 { font-size:2em; }
    h1,h2 { border-bottom:1px solid #8884; padding-bottom:.4em; }
    a { color:#5283d9; } pre,code { font-family:ui-monospace,monospace; font-size:.9em; }
    pre { padding:16px; overflow:auto; background:#8882; border-radius:8px; } code { background:#8882; padding:2px 4px; border-radius:4px; } pre code { padding:0; background:none; }
    blockquote { margin-left:0; padding-left:16px; border-left:3px solid #bd8551; opacity:.8; }
    table { border-collapse:collapse; display:block; overflow:auto; } th,td { border:1px solid #8885; padding:7px 12px; }
    img { max-width:100%; } hr { border:0; border-top:1px solid #8884; } input { pointer-events:none; }
    """
}
