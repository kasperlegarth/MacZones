import AppKit

/// Decides which zones are targeted during a drag and moves windows into them.
@MainActor
final class ZoneEngine {
    private let store: LayoutStore
    private let overlay = OverlayController()

    private var screen: NSScreen?
    private var anchor: Int?
    private var targetRect: CGRect?

    init(store: LayoutStore) {
        self.store = store
    }

    // MARK: Dragging

    func dragChanged(cursor: CGPoint, modifiers: NSEvent.ModifierFlags) {
        let shift = modifiers.contains(.shift)
        let active = store.config.activation == .shift ? shift : !shift
        guard active, let screen = NSScreen.containing(axPoint: cursor) else {
            cancelDrag()
            return
        }

        let zones = store.zoneRects(for: screen)
        guard let current = zoneIndex(at: cursor, in: zones) else {
            // Between zones (in the spacing): keep the previous target to avoid flicker.
            if let previous = self.screen, previous == screen, let targetRect {
                overlay.show(on: screen, zones: zones, highlighted: indices(inside: targetRect, zones: zones))
            }
            return
        }

        if screen != self.screen { anchor = nil }
        self.screen = screen

        // Hold Control to span multiple zones, starting at the zone where Control was pressed.
        if modifiers.contains(.control), let anchor, anchor < zones.count {
            targetRect = zones[anchor].union(zones[current])
        } else {
            anchor = current
            targetRect = zones[current]
        }

        overlay.show(on: screen, zones: zones, highlighted: indices(inside: targetRect!, zones: zones))
    }

    func dragEnded(window: AXWindow) {
        if let targetRect {
            window.setFrame(targetRect)
        }
        cancelDrag()
    }

    func cancelDrag() {
        overlay.hide()
        screen = nil
        anchor = nil
        targetRect = nil
    }

    private func zoneIndex(at point: CGPoint, in zones: [CGRect]) -> Int? {
        // Prefer the smallest zone when zones overlap, so nested zones stay reachable.
        zones.indices
            .filter { zones[$0].contains(point) }
            .min { zones[$0].area < zones[$1].area }
    }

    private func indices(inside rect: CGRect, zones: [CGRect]) -> Set<Int> {
        Set(zones.indices.filter { rect.insetBy(dx: -1, dy: -1).contains(zones[$0]) })
    }

    // MARK: Keyboard

    /// Moves the focused window to the next/previous zone, continuing onto neighbouring screens.
    func moveFocusedWindow(by step: Int) {
        guard let window = AXWindow.focused(), let frame = window.frame else { return }

        let slots: [CGRect] = NSScreen.screens
            .sorted { $0.axFrame.minX < $1.axFrame.minX }
            .flatMap { store.zoneRects(for: $0) }
        guard !slots.isEmpty else { return }

        let target: Int
        if let current = slots.firstIndex(where: { $0.isClose(to: frame) }) {
            target = (current + step + slots.count) % slots.count
        } else {
            // Not snapped yet: pick the zone nearest the window's center on its screen.
            let nearest = slots.indices.min {
                slots[$0].center.distance(to: frame.center) < slots[$1].center.distance(to: frame.center)
            }!
            target = nearest
        }
        window.setFrame(slots[target])
    }

    /// Moves the focused window to zone `number` (1-based) on the screen it is on.
    func moveFocusedWindow(toZone number: Int) {
        guard let window = AXWindow.focused(), let frame = window.frame,
              let screen = NSScreen.best(for: frame) else { return }
        let zones = store.zoneRects(for: screen)
        guard number >= 1, number <= zones.count else { return }
        window.setFrame(zones[number - 1])
    }
}

private extension CGRect {
    func isClose(to other: CGRect, tolerance: CGFloat = 24) -> Bool {
        abs(minX - other.minX) < tolerance && abs(minY - other.minY) < tolerance
            && abs(width - other.width) < tolerance && abs(height - other.height) < tolerance
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
