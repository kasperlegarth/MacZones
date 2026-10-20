import AppKit
import ApplicationServices

enum Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func promptIfNeeded() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

extension AXUIElement {
    func value(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    func element(_ attribute: String) -> AXUIElement? {
        guard let value = value(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    var role: String? { value(kAXRoleAttribute as String) as? String }

    var pid: pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(self, &pid)
        return pid
    }
}

/// A window of another application, controlled through the Accessibility API.
struct AXWindow {
    let element: AXUIElement

    var pid: pid_t { element.pid }

    /// The window under a point given in global Accessibility coordinates.
    static func at(_ point: CGPoint) -> AXWindow? {
        var hit: AXUIElement?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success,
              var element = hit else { return nil }

        for _ in 0..<32 {
            if element.role == kAXWindowRole as String { return AXWindow(element: element) }
            if let window = element.element(kAXWindowAttribute as String) { return AXWindow(element: window) }
            guard let parent = element.element(kAXParentAttribute as String) else { return nil }
            element = parent
        }
        return nil
    }

    static func focused() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        return appElement.element(kAXFocusedWindowAttribute as String).map(AXWindow.init)
    }

    var frame: CGRect? {
        guard let positionValue = element.value(kAXPositionAttribute as String),
              let sizeValue = element.value(kAXSizeAttribute as String) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    func setFrame(_ rect: CGRect) {
        // Apps with AXEnhancedUserInterface enabled animate (slowly) when moved; disable it temporarily.
        let app = AXUIElementCreateApplication(pid)
        let enhanced = app.value("AXEnhancedUserInterface") as? Bool ?? false
        if enhanced {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
        }
        defer {
            if enhanced {
                AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            }
        }

        // Size, position, size: the second resize fixes windows that were clamped by the old screen.
        setSize(rect.size)
        setPosition(rect.origin)
        setSize(rect.size)
    }

    private func setPosition(_ point: CGPoint) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func setSize(_ size: CGSize) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }
}
