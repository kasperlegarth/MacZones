import AppKit

/// Cocoa uses a bottom-left origin on the primary screen; Accessibility uses top-left.
/// Flipping is symmetric, so the same functions convert both ways.
enum Geometry {
    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    static func flip(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func flip(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    static var mouseLocation: CGPoint { flip(NSEvent.mouseLocation) }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    /// Stable across reboots and reconnects, unlike the display id.
    var stableID: String {
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return String(displayID)
    }

    var axFrame: CGRect { Geometry.flip(frame) }
    var axVisibleFrame: CGRect { Geometry.flip(visibleFrame) }

    static func containing(axPoint point: CGPoint) -> NSScreen? {
        screens.first { $0.axFrame.contains(point) } ?? main
    }

    /// The screen showing the largest part of a rect (in Accessibility coordinates).
    static func best(for rect: CGRect) -> NSScreen? {
        screens.max { a, b in
            a.axFrame.intersection(rect).area < b.axFrame.intersection(rect).area
        } ?? main
    }
}

extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
