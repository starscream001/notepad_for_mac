import AppKit
import Foundation

// Original vector artwork: an origami fox with a code badge. No external assets.
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func polygon(_ points: [(CGFloat, CGFloat)], _ fill: UInt32) {
    let path = NSBezierPath(); path.move(to: NSPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
    path.close(); color(fill).setFill(); path.fill()
}
for (name, size) in [("icon_16x16",16), ("icon_16x16@2x",32), ("icon_32x32",32), ("icon_32x32@2x",64), ("icon_128x128",128), ("icon_128x128@2x",256), ("icon_256x256",256), ("icon_256x256@2x",512), ("icon_512x512",512), ("icon_512x512@2x",1024)] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(size) / 1024); transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 195, yRadius: 195)
    NSGradient(starting: color(0x102631), ending: color(0x24515A))!.draw(in: tile, angle: 90)
    // Ear silhouettes and folded inner paper.
    polygon([(246,804),(455,714),(286,492)], 0xFFAD59)
    polygon([(778,804),(569,714),(738,492)], 0xE77635)
    polygon([(280,746),(411,696),(307,571)], 0x753E39)
    polygon([(744,746),(613,696),(717,571)], 0x60333B)
    // Broad angular head; each polygon is a visible origami fold.
    polygon([(286,492),(455,714),(512,742),(569,714),(738,492),(645,404),(512,330),(379,404)], 0xF5903D)
    polygon([(286,492),(455,714),(512,742),(512,566)], 0xFFB15C)
    polygon([(512,742),(569,714),(738,492),(512,566)], 0xEB7832)
    polygon([(455,714),(512,742),(512,566)], 0xFFD18A)
    polygon([(512,742),(569,714),(512,566)], 0xF99D47)
    polygon([(286,492),(420,548),(512,430),(512,330),(379,404)], 0xFFF0D8)
    polygon([(738,492),(604,548),(512,430),(512,330),(645,404)], 0xEBD4BB)
    polygon([(379,404),(512,430),(512,330)], 0xF8DDB9)
    polygon([(645,404),(512,430),(512,330)], 0xD6B89C)
    // Eyes and a folded triangular nose remain legible at small sizes.
    polygon([(365,566),(437,547),(426,520),(383,537)], 0x182F39)
    polygon([(659,566),(587,547),(598,520),(641,537)], 0x182F39)
    polygon([(476,437),(548,437),(512,398)], 0x182F39)
    // A restrained editor badge, omitted only at the tiny 16px size.
    if size >= 32 {
        color(0xECF4EF).setFill()
        NSBezierPath(roundedRect: NSRect(x: 354, y: 166, width: 316, height: 116), xRadius: 34, yRadius: 34).fill()
        let mark = "</>" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 78, weight: .bold), .foregroundColor: color(0x183A45)]
        let measured = mark.size(withAttributes: attributes)
        mark.draw(at: NSPoint(x: 512 - measured.width / 2, y: 224 - measured.height / 2), withAttributes: attributes)
    }
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination).appendingPathComponent(name + ".png"))
}
