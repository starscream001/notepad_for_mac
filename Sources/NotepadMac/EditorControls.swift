import AppKit

final class EditorButtonCell: NSButtonCell {
    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        let readable = NSMutableAttributedString(attributedString: title)
        readable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: readable.length))
        return super.drawTitle(readable, withFrame: frame, in: controlView)
    }
    override func drawBezel(withFrame frame: NSRect, in view: NSView) {
        let rect = frame.insetBy(dx: 1, dy: 2)
        let selected = state == .on
        (selected ? NSColor.controlAccentColor.withAlphaComponent(0.16) : NSColor.controlBackgroundColor).setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        path.fill()
        (selected ? NSColor.controlAccentColor.withAlphaComponent(0.5) : NSColor.separatorColor.withAlphaComponent(0.5)).setStroke()
        path.lineWidth = 0.75; path.stroke()
        if isHighlighted { NSColor.labelColor.withAlphaComponent(0.08).setFill(); path.fill() }
    }
}

final class TabSurface: NSView {
    var selected = false { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ rect: NSRect) {
        (selected ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.labelColor.withAlphaComponent(0.035)).setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 9, yRadius: 9)
        path.fill()
        if selected { NSColor.controlAccentColor.withAlphaComponent(0.4).setStroke(); path.lineWidth = 1; path.stroke() }
    }
}
