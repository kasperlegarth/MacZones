import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = LayoutStore.shared
    private lazy var engine = ZoneEngine(store: store)
    private lazy var dragMonitor = DragMonitor(engine: engine)

    private var statusItem: NSStatusItem!
    private var editorWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Permissions.promptIfNeeded()
        LaunchAtLogin.enableOnFirstInstall()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "MacZones")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        dragMonitor.start()

        store.$config
            .map(\.hotkeysEnabled)
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    Shortcuts.register(engine: self.engine)
                } else {
                    HotKeyCenter.shared.unregisterAll()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !Permissions.isTrusted {
            let item = NSMenuItem(title: "⚠️ Giv adgang under Tilgængelighed…", action: #selector(openAccessibility), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            menu.addItem(.separator())
        }

        let screens = NSScreen.screens
        for screen in screens {
            if screens.count > 1 {
                let header = NSMenuItem(title: screen.localizedName, action: nil, keyEquivalent: "")
                header.isEnabled = false
                menu.addItem(header)
            }
            let current = store.layout(for: screen).id
            for layout in store.allLayouts {
                let item = NSMenuItem(title: layout.name, action: #selector(selectLayout(_:)), keyEquivalent: "")
                item.target = self
                item.state = layout.id == current ? .on : .off
                item.representedObject = LayoutChoice(layoutID: layout.id, screenID: screen.stableID)
                if screens.count > 1 { item.indentationLevel = 1 }
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let editor = NSMenuItem(title: "Rediger layouts…", action: #selector(openEditor), keyEquivalent: ",")
        editor.target = self
        menu.addItem(editor)
        let login = NSMenuItem(title: "Start ved login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Afslut MacZones", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? LayoutChoice,
              let screen = NSScreen.screens.first(where: { $0.stableID == choice.screenID }) else { return }
        store.assign(choice.layoutID, to: screen)
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        if LaunchAtLogin.requiresApproval { LaunchAtLogin.openSystemSettings() }
    }

    @objc private func openAccessibility() {
        Permissions.promptIfNeeded()
        LaunchAtLogin.enableOnFirstInstall()
        Permissions.openSystemSettings()
    }

    @objc func openEditor() {
        if editorWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "MacZones"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: EditorView().environmentObject(store))
            window.setContentSize(NSSize(width: 900, height: 600))
            window.center()
            editorWindow = window
        }
        NSApp.activate()
        editorWindow?.makeKeyAndOrderFront(nil)
    }
}

private final class LayoutChoice: NSObject {
    let layoutID: UUID
    let screenID: String

    init(layoutID: UUID, screenID: String) {
        self.layoutID = layoutID
        self.screenID = screenID
    }
}
