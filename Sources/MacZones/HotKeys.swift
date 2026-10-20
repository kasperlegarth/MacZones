import Carbon

/// Global keyboard shortcuts via the Carbon hot key API (no extra permission required).
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private var installed = false

    func register(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        installIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x4D5A_4E53), id: nextID) // "MZNS"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return }
        refs.append(ref)
        handlers[nextID] = handler
        nextID += 1
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        handlers.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        handlers[id]?()
    }

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            let id = hotKeyID.id
            MainActor.assumeIsolated { HotKeyCenter.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

enum Shortcuts {
    static let modifiers = controlKey | optionKey
    static let numberKeys = [
        kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
        kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
    ]

    @MainActor
    static func register(engine: ZoneEngine) {
        let center = HotKeyCenter.shared
        center.unregisterAll()
        center.register(keyCode: kVK_LeftArrow, modifiers: modifiers) { engine.moveFocusedWindow(by: -1) }
        center.register(keyCode: kVK_RightArrow, modifiers: modifiers) { engine.moveFocusedWindow(by: 1) }
        for (index, key) in numberKeys.enumerated() {
            center.register(keyCode: key, modifiers: modifiers) { engine.moveFocusedWindow(toZone: index + 1) }
        }
    }
}
