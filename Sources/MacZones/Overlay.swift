import AppKit
import SwiftUI

final class OverlayModel: ObservableObject {
    /// Zone rects local to the overlay window, top-left origin.
    @Published var zones: [CGRect] = []
    @Published var highlighted: Set<Int> = []
}

/// Transparent, click-through window drawn above everything on one screen.
final class OverlayWindow: NSPanel {
    let model = OverlayModel()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = NSHostingView(rootView: OverlayView(model: model))
    }
}

struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.zones.enumerated()), id: \.offset) { index, rect in
                let on = model.highlighted.contains(index)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? Color.accentColor.opacity(0.42) : Color.black.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(on ? Color.accentColor : Color.white.opacity(0.55), lineWidth: on ? 3 : 1.5)
                    )
                    .overlay(
                        Text("\(index + 1)")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(on ? 1 : 0.7))
                            .shadow(radius: 4)
                    )
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.08), value: model.highlighted)
    }
}

@MainActor
final class OverlayController {
    private let window = OverlayWindow()
    private var screenID: String?

    func show(on screen: NSScreen, zones: [CGRect], highlighted: Set<Int>) {
        let frame = screen.axVisibleFrame
        if screenID != screen.stableID {
            screenID = screen.stableID
            window.setFrame(screen.visibleFrame, display: false)
        }
        window.model.zones = zones.map { $0.offsetBy(dx: -frame.minX, dy: -frame.minY) }
        window.model.highlighted = highlighted
        if !window.isVisible { window.orderFrontRegardless() }
    }

    func hide() {
        window.orderOut(nil)
        screenID = nil
    }
}
