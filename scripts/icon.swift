import AppKit
import Foundation

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for (name, size) in [("icon_16x16",16), ("icon_16x16@2x",32), ("icon_32x32",32), ("icon_32x32@2x",64), ("icon_128x128",128), ("icon_128x128@2x",256), ("icon_256x256",256), ("icon_256x256@2x",512), ("icon_512x512",512), ("icon_512x512@2x",1024)] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.34, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 195, yRadius: 195).fill()
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 260, y: 190, width: 504, height: 644), xRadius: 38, yRadius: 38).fill()
    NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.34, alpha: 1).setStroke()
    let lines = NSBezierPath(); lines.lineWidth = 26; lines.lineCapStyle = .round
    for y in [650, 540, 430, 320] { lines.move(to: NSPoint(x: 350, y: y)); lines.line(to: NSPoint(x: y == 320 ? 560 : 674, y: y)) }
    lines.stroke()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination).appendingPathComponent(name + ".png"))
}
