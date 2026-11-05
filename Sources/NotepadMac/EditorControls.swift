import AppKit

struct ColorScheme: Decodable {
    let id: String, ru: String, en: String, background: String, accent: String
    let dark: Bool
    static let all: [ColorScheme] = {
        guard let url = Bundle.main.url(forResource: "Palettes", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ColorScheme].self, from: data)) ?? []
    }()
    static var current: ColorScheme? { all.first { $0.id == UserDefaults.standard.string(forKey: "colorScheme") } }
}
enum EditorPalette {
    static let label = NSColor(name: NSColor.Name("EditorLabel")) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .labelColor : .black
    }
    static let text = NSColor(name: NSColor.Name("EditorText")) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .textColor : .black
    }
    static func hex(_ text: String) -> NSColor {
        let n = UInt32(text.dropFirst(), radix: 16) ?? 0
        return NSColor(srgbRed: CGFloat((n >> 16) & 255)/255, green: CGFloat((n >> 8) & 255)/255, blue: CGFloat(n & 255)/255, alpha: 1)
    }
    static func adaptive(_ name: String, light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat), role: String) -> NSColor {
        NSColor(name: NSColor.Name(name)) { appearance in
            if let scheme = ColorScheme.current {
                let bg = hex(scheme.background), accent = hex(scheme.accent)
                let fg: NSColor = scheme.dark ? .white : .black
                switch role {
                case "editor": return bg
                case "accent": return accent
                case "selected": return bg.blended(withFraction: 0.22, of: accent) ?? bg
                case "button": return bg.blended(withFraction: scheme.dark ? 0.09 : 0.10, of: scheme.dark ? fg : accent) ?? bg
                default: return scheme.dark ? (bg.blended(withFraction: 0.04, of: fg) ?? bg) : bg
                }
            }
            let c = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        }
    }
    static let chrome = adaptive("EditorChrome", light: (1,1,1), dark: (0.14,0.14,0.22), role: "chrome")
    static let editor = adaptive("EditorCanvas", light: (1,1,1), dark: (0.09,0.09,0.15), role: "editor")
    static let button = adaptive("EditorControl", light: (0.95,0.95,0.95), dark: (0.17,0.17,0.26), role: "button")
    static let selected = adaptive("EditorSelected", light: (0.89,0.88,0.94), dark: (0.23,0.21,0.30), role: "selected")
    static let accent = adaptive("EditorAccent", light: (0.64,0.32,0.10), dark: (0.94,0.65,0.38), role: "accent")
}

final class EditorBar: NSStackView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        DispatchQueue.main.async {
            guard let app = NSApp.delegate as? AppDelegate, app.window != nil else { return }
            app.refreshSchemes()
            app.window.contentView?.needsDisplay = true
            app.tabs.forEach { $0.highlight(); $0.ruler.needsDisplay = true }
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: bounds).addClip()
        EditorPalette.chrome.setFill(); bounds.fill()
        NSColor.separatorColor.setFill(); NSRect(x:0,y:0,width:bounds.width,height:1).fill()
    }
}

final class EditorButtonCell: NSButtonCell {
    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        let readable = NSMutableAttributedString(attributedString: title)
        readable.addAttribute(.foregroundColor, value: EditorPalette.label, range: NSRange(location: 0, length: readable.length))
        return super.drawTitle(readable, withFrame: frame, in: controlView)
    }
    override func drawBezel(withFrame frame: NSRect, in view: NSView) {
        let rect = frame.insetBy(dx: 1, dy: 1)
        (state == .on ? EditorPalette.selected : EditorPalette.button).setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7); path.fill()
        if isHighlighted { NSColor.labelColor.withAlphaComponent(0.08).setFill(); path.fill() }
    }
}

final class EditorPopupCell: NSPopUpButtonCell {
    override func draw(withFrame frame: NSRect, in view: NSView) {
        EditorPalette.button.setFill()
        NSBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7).fill()
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: EditorPalette.label, .paragraphStyle: style]
        let text = (selectedItem?.title ?? title) as NSString
        let height = text.size(withAttributes: attributes).height
        text.draw(in: NSRect(x: frame.minX + 10, y: frame.midY - height / 2, width: max(0, frame.width - 34), height: height), withAttributes: attributes)
        let arrow = NSBezierPath(); arrow.move(to: NSPoint(x: frame.maxX-20, y: frame.midY-2)); arrow.line(to: NSPoint(x: frame.maxX-16, y: frame.midY+2)); arrow.line(to: NSPoint(x: frame.maxX-12, y: frame.midY-2)); arrow.lineWidth = 1.4
        NSColor.secondaryLabelColor.setStroke(); arrow.stroke()
    }
}

final class TabSurface: NSView {
    var selected = false { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ rect: NSRect) {
        (selected ? EditorPalette.selected : EditorPalette.chrome).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7).fill()
    }
}

final class EditorListStack: NSStackView {
    override var isFlipped: Bool { true }
}

final class RenamableButton: NSButton {
    var onRename: (() -> Void)?
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onRename?() } else { super.mouseDown(with: event) }
    }
}

final class EditorSidebar: NSStackView {
    override func draw(_ dirtyRect: NSRect) {
        EditorPalette.button.withAlphaComponent(0.45).setFill(); bounds.fill()
        NSColor.separatorColor.setFill(); NSRect(x:bounds.maxX-1,y:0,width:1,height:bounds.height).fill()
    }
}

final class SidebarNoteCell: NSButtonCell {
    override func drawBezel(withFrame frame:NSRect,in view:NSView) {
        guard state == .on || isHighlighted else { return }
        EditorPalette.button.setFill();NSBezierPath(roundedRect:frame.insetBy(dx:1,dy:1),xRadius:5,yRadius:5).fill()
    }
    override func drawTitle(_ title:NSAttributedString,withFrame frame:NSRect,in view:NSView)->NSRect {
        let text=NSMutableAttributedString(attributedString:title);text.addAttribute(.foregroundColor,value:EditorPalette.label,range:NSRange(location:0,length:text.length));return super.drawTitle(text,withFrame:frame,in:view)
    }
}
