import AppKit
import NotepadCore

final class CodeTextView: NSTextView {
    var tabWidth = 4
    override func insertTab(_ sender: Any?) {
        let position = TextPosition.lineColumn(in: string, utf16Offset: selectedRange().location)
        insertText(String(repeating: " ", count: tabWidth - ((position.column - 1) % tabWidth)), replacementRange: selectedRange())
    }
    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let range = ns.lineRange(for: NSRange(location: selectedRange().location, length: 0))
        let prefix = ns.substring(with: NSRange(location: range.location, length: selectedRange().location - range.location))
        let indent = String(prefix.prefix { $0 == " " || $0 == "\t" })
        super.insertNewline(sender)
        if !indent.isEmpty { insertText(indent, replacementRange: selectedRange()) }
    }
}

final class LineRuler: NSView {
    let ruleThickness: CGFloat = 48
    var observer: NSObjectProtocol?
    override var isFlipped: Bool { true }
    weak var editor: NSTextView?
    init(editor: NSTextView, scroll: NSScrollView) {
        self.editor = editor
        super.init(frame: .zero)
        wantsLayer = true; layer?.masksToBounds = true
        scroll.contentView.postsBoundsChangedNotifications = true
        observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak self] _ in self?.needsDisplay = true }
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    override func draw(_ rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: bounds).addClip()
        EditorPalette.editor.setFill(); bounds.fill()
        guard let editor, let layout = editor.layoutManager, let container = editor.textContainer else { return }
        let ns = editor.string as NSString
        let visible = layout.glyphRange(forBoundingRect: editor.visibleRect, in: container)
        let chars = layout.characterRange(forGlyphRange: visible, actualGlyphRange: nil)
        var index = ns.lineRange(for: NSRange(location: min(chars.location, ns.length), length: 0)).location
        var line = TextPosition.lineColumn(in: editor.string, utf16Offset: index).line
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]
        while index <= min(NSMaxRange(chars), ns.length) {
            if index == ns.length && ns.length > 0 && !editor.string.hasSuffix("\n") { break }
            var glyph = NSRect.zero
            if index < ns.length {
                glyph = layout.lineFragmentRect(forGlyphAt: layout.glyphIndexForCharacter(at: index), effectiveRange: nil)
            } else { glyph = layout.extraLineFragmentRect }
            let y = editor.convert(NSPoint(x: 0, y: glyph.minY + editor.textContainerOrigin.y), to: self).y
            let label = "\(line)" as NSString
            label.draw(at: NSPoint(x: ruleThickness - label.size(withAttributes: attributes).width - 12, y: y), withAttributes: attributes)
            if index >= ns.length { break }
            let next = NSMaxRange(ns.lineRange(for: NSRange(location: index, length: 0)))
            if next <= index { break }
            index = next; line += 1
        }
    }
}

final class EditorTab {
    var snapshot: SessionTab
    let container = NSView()
    let scroll = NSScrollView()
    let textView = CodeTextView()
    var ruler: LineRuler!
    var savedEncoding: TextEncoding
    var savedEnding: LineEnding
    var highlightWork: DispatchWorkItem?
    var dirty: Bool { textView.string != snapshot.savedText || snapshot.encoding != savedEncoding || snapshot.lineEnding != savedEnding }
    var url: URL? { snapshot.path.map { URL(fileURLWithPath: $0) } }
    var language: String { snapshot.syntaxLanguage ?? Syntax.language(for: url?.pathExtension ?? "") }

    init(_ snapshot: SessionTab, fontSize: CGFloat, wrap: Bool) {
        self.snapshot = snapshot; savedEncoding = snapshot.encoding; savedEnding = snapshot.lineEnding
        textView.isRichText = false; textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = EditorPalette.editor; textView.textColor = .textColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.minSize = .zero; textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true; textView.autoresizingMask = [.width]
        textView.string = snapshot.text
        textView.setAccessibilityLabel(snapshot.title)
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.documentView = textView
        ruler = LineRuler(editor: textView, scroll: scroll)
        container.wantsLayer = true; container.layer?.masksToBounds = true
        for view in [ruler!, scroll] { view.translatesAutoresizingMaskIntoConstraints = false; container.addSubview(view) }
        NSLayoutConstraint.activate([
            ruler.leadingAnchor.constraint(equalTo: container.leadingAnchor), ruler.widthAnchor.constraint(equalToConstant: 48),
            ruler.topAnchor.constraint(equalTo: container.topAnchor), ruler.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: ruler.trailingAnchor), scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: container.topAnchor), scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        setWrap(wrap)
        textView.setSelectedRange(NSRange(location: min(snapshot.selection, (snapshot.text as NSString).length), length: 0))
    }
    func setWrap(_ wrap: Bool) {
        scroll.hasHorizontalScroller = !wrap
        textView.isHorizontallyResizable = !wrap
        textView.textContainer?.widthTracksTextView = wrap
        textView.textContainer?.containerSize = NSSize(width: wrap ? max(100, scroll.contentSize.width) : CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        if wrap { textView.setFrameSize(NSSize(width: max(100, scroll.contentSize.width), height: textView.frame.height)) }
    }
    func capture() -> SessionTab {
        snapshot.text = textView.string; snapshot.selection = textView.selectedRange().location
        return snapshot
    }
    func highlight() {
        highlightWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Syntax.apply(to: self.textView, language: self.language)
        }
        highlightWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }
}

enum Syntax {
    static func color(_ name: String, light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> NSColor {
        NSColor(name: NSColor.Name(name)) { appearance in
            let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
    }
    static let numberColor = color("SyntaxNumber", light: (0.55, 0.30, 0.04), dark: (0.95, 0.73, 0.43))
    static let keywordColor = color("SyntaxKeyword", light: (0.44, 0.18, 0.65), dark: (0.82, 0.64, 0.95))
    static let stringColor = color("SyntaxString", light: (0.13, 0.44, 0.23), dark: (0.55, 0.84, 0.63))
    static let markupColor = color("SyntaxMarkup", light: (0.14, 0.35, 0.65), dark: (0.54, 0.71, 0.97))
    static let languages = ["Обычный текст", "SQL", "Kafka / ksqlDB", "Swift", "JavaScript", "TypeScript", "Python", "JSON", "HTML / XML", "CSS", "C / C++", "Markdown", "Shell", "YAML"]
    static func language(for ext: String) -> String {
        if let queryLanguage = QuerySyntax.language(forExtension: ext) { return queryLanguage }
        switch ext.lowercased() {
        case "swift": return "Swift"
        case "js", "jsx", "mjs", "cjs": return "JavaScript"
        case "ts", "tsx": return "TypeScript"
        case "py", "pyw": return "Python"
        case "json": return "JSON"
        case "html", "htm", "xml", "svg": return "HTML / XML"
        case "css", "scss": return "CSS"
        case "c", "h", "cpp", "hpp", "cc", "m", "mm": return "C / C++"
        case "md", "markdown": return "Markdown"
        case "sh", "zsh", "bash": return "Shell"
        case "yml", "yaml": return "YAML"
        default: return "Обычный текст"
        }
    }
    static func apply(to view: NSTextView, language: String) {
        guard let storage = view.textStorage else { return }
        let text = view.string
        let full = NSRange(location: 0, length: (text as NSString).length)
        storage.beginEditing()
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: full)
        defer { storage.endEditing() }
        // Keep very large documents responsive; basic editing still works.
        guard full.length < 500_000, language != "Обычный текст" else { return }
        if language == "SQL" || language == "Kafka / ksqlDB" {
            for token in QuerySyntax.tokens(in: text, kafkaMode: language == "Kafka / ksqlDB") {
                let color: NSColor
                switch token.kind {
                case .keyword: color = keywordColor
                case .string: color = stringColor
                case .identifier, .function: color = markupColor
                case .number, .parameter: color = numberColor
                case .comment: color = .secondaryLabelColor
                }
                storage.addAttribute(.foregroundColor, value: color, range: token.range)
            }
            return
        }
        var rules: [(String, NSColor)] = [
            (#"\b\d+(?:\.\d+)?\b"#, numberColor),
            (#"\b(?:let|var|const|func|function|class|struct|enum|protocol|extension|import|from|return|if|else|for|while|in|do|try|catch|throw|throws|async|await|public|private|static|final|override|guard|switch|case|break|continue|def|lambda|with|as|pass|yield|None|True|False|true|false|null|nil|new|this|self|typeof|interface|export|default|type|void|int|float|double|char|bool|include)\b"#, keywordColor),
            (#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#, stringColor)
        ]
        if ["HTML / XML"].contains(language) { rules.insert((#"</?[\w:-]+|/?>"#, markupColor), at: 0) }
        if language == "Markdown" { rules.append((#"(?m)^#{1,6}\s.*$|\*\*[^\n]+?\*\*"#, markupColor)) }
        if ["Python", "Shell", "YAML"].contains(language) { rules.append((#"(?m)#.*$"#, .secondaryLabelColor)) }
        else if language == "HTML / XML" { rules.append((#"<!--[\s\S]*?-->"#, .secondaryLabelColor)) }
        else if language != "JSON" { rules.append((#"//[^\n]*|/\*[\s\S]*?\*/"#, .secondaryLabelColor)) }
        for (pattern, color) in rules {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            regex.enumerateMatches(in: text, range: full) { match, _, _ in
                if let match { storage.addAttribute(.foregroundColor, value: color, range: match.range) }
            }
        }
    }
}
