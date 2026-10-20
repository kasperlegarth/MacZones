// Renders the app icon to a 1024×1024 PNG: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// macOS icon grid: 824pt body centered in 1024pt canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
NSColor.black.setFill()
squircle.fill()
NSGraphicsContext.current?.restoreGraphicsState()

NSGradient(
    starting: NSColor(red: 0.18, green: 0.22, blue: 0.36, alpha: 1),
    ending: NSColor(red: 0.07, green: 0.08, blue: 0.15, alpha: 1)
)!.draw(in: squircle, angle: -90)

// Priority layout: 25% / 50% / 25% zones.
let inset: CGFloat = 92
let gap: CGFloat = 34
let area = body.insetBy(dx: inset, dy: inset)
let unit = (area.width - gap * 2) / 4
let zones = [
    NSRect(x: area.minX, y: area.minY, width: unit, height: area.height),
    NSRect(x: area.minX + unit + gap, y: area.minY, width: unit * 2, height: area.height),
    NSRect(x: area.minX + unit * 3 + gap * 2, y: area.minY, width: unit, height: area.height),
]
for (index, zone) in zones.enumerated() {
    let path = NSBezierPath(roundedRect: zone, xRadius: 38, yRadius: 38)
    if index == 1 {
        NSGradient(
            starting: NSColor(red: 0.36, green: 0.64, blue: 1.0, alpha: 1),
            ending: NSColor(red: 0.20, green: 0.42, blue: 0.95, alpha: 1)
        )!.draw(in: path, angle: -90)
    } else {
        NSColor.white.withAlphaComponent(0.14).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.35).setStroke()
        path.lineWidth = 6
        path.stroke()
    }
}

image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
