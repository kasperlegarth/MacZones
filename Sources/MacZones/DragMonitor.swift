import AppKit

/// Watches global mouse events and detects when the user is dragging another app's window.
@MainActor
final class DragMonitor {
    private let engine: ZoneEngine
    private var monitors: [Any] = []

    private var window: AXWindow?
    private var startFrame: CGRect?
    private var isWindowDrag = false

    init(engine: ZoneEngine) {
        self.engine = engine
    }

    func start() {
        guard monitors.isEmpty else { return }
        add(.leftMouseDown) { monitor, _ in monitor.mouseDown() }
        add(.leftMouseDragged) { $0.mouseDragged($1) }
        add(.leftMouseUp) { monitor, _ in monitor.mouseUp() }
        add(.flagsChanged) { $0.flagsChanged($1) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        reset()
    }

    private func add(_ mask: NSEvent.EventTypeMask, _ handler: @escaping (DragMonitor, NSEvent) -> Void) {
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self, event)
            }
        }
        if let monitor { monitors.append(monitor) }
    }

    private func mouseDown() {
        reset()
        guard let candidate = AXWindow.at(Geometry.mouseLocation),
              candidate.pid != ProcessInfo.processInfo.processIdentifier else { return }
        window = candidate
        startFrame = candidate.frame
    }

    private func mouseDragged(_ event: NSEvent) {
        guard let window else { return }

        if !isWindowDrag {
            // It is a window move (not a resize, text selection, etc.) once the origin moves but the size doesn't.
            guard let startFrame, let frame = window.frame else { return }
            let moved = abs(frame.minX - startFrame.minX) > 1 || abs(frame.minY - startFrame.minY) > 1
            let resized = abs(frame.width - startFrame.width) > 1 || abs(frame.height - startFrame.height) > 1
            if resized { self.window = nil; return }
            guard moved else { return }
            isWindowDrag = true
        }

        engine.dragChanged(cursor: Geometry.mouseLocation, modifiers: event.modifierFlags)
    }

    private func flagsChanged(_ event: NSEvent) {
        guard isWindowDrag else { return }
        engine.dragChanged(cursor: Geometry.mouseLocation, modifiers: event.modifierFlags)
    }

    private func mouseUp() {
        if isWindowDrag, let window {
            engine.dragEnded(window: window)
        }
        reset()
    }

    private func reset() {
        window = nil
        startFrame = nil
        isWindowDrag = false
    }
}
