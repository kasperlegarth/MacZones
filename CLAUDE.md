# MacZones

A FancyZones-style window manager for macOS (menu bar app). Swift Package, no Xcode project, no dependencies.
The UI is in Danish; code and comments are in English. Answer the user in the language they write in.

## Installing for a user

When the user asks to install, set up or build MacZones ("Installér MacZones", "set it up", …), do this in order:

1. **Check prerequisites.**
   - `sw_vers -productVersion` must be 14.0 or newer.
   - `swift --version` must be Swift 6.0 or newer. If `swift` is missing or older, or `xcode-select -p` points at
     CommandLineTools without a recent toolchain, ask the user to install Xcode 16+ from the App Store, open it once,
     and run `sudo xcodebuild -license accept`. Stop until they confirm.
2. **Create the signing certificate:** `./scripts/create-signing-cert.sh` (it does nothing if it already exists).
   It adds a self-signed "MacZones Dev" code signing certificate to the login keychain. Tell the user it is local only
   and why it is needed (see Signing below). macOS may ask for the keychain password; that is expected.
3. **Build and install:** `./scripts/install.sh`. It builds a release build, copies it to `/Applications/MacZones.app`
   and launches it. Confirm it runs: `pgrep -lf /Applications/MacZones.app`.
4. **Accessibility permission.** On first launch macOS shows "MacZones vil gerne styre denne Mac". Tell the user to click
   *Åbn Systemindstillinger* and turn MacZones on under Privacy & Security → Accessibility. You cannot grant it for them.
   You cannot read the permission state directly, so ask the user to drag a window by its title bar while holding
   ⇧ Shift; the zones should appear and the window should snap when released.
5. **Explain usage briefly:** the menu bar icon, drag with ⇧ Shift to snap, ⌃ Control to span zones,
   ⌃⌥←/→ and ⌃⌥1–9 shortcuts, "Rediger layouts…" for the editor. Launch at login is enabled automatically on the
   first run from `/Applications` and can be toggled in the menu.

### Troubleshooting

- **Toggle is on but nothing happens when dragging:** the permission belongs to an older signature.
  Run `tccutil reset Accessibility com.kasperlegarth.MacZones`, relaunch with `open /Applications/MacZones.app`,
  and have the user grant the permission again.
- **Build warns "signing ad-hoc":** the certificate is missing; run `./scripts/create-signing-cert.sh` and rebuild.
- **Crash:** reports are in `~/Library/Logs/DiagnosticReports/MacZones-*.ips`; the crashing frame names the Swift file and line.

## Signing

Ad-hoc signed builds get a new identity every build, so macOS silently drops the Accessibility permission (the toggle
stays on but no longer applies). `build-app.sh` signs with `$SIGN_IDENTITY`, else the "MacZones Dev" certificate,
else ad-hoc. Never switch the default to ad-hoc. The local certificate is not trusted on other Macs; distributing a
prebuilt app needs an Apple Developer ID and notarization.

## Development

- Build: `swift build`. App bundle: `./scripts/build-app.sh` (outputs `build/MacZones.app`). Install: `./scripts/install.sh`.
- There are no tests; verify by building and running the installed app.
- `Resources/Info.plist` is copied into the bundle by `build-app.sh`; bump `CFBundleShortVersionString` for releases.
- The icon is generated: edit `scripts/make-icon.swift`, then run `./scripts/make-icon.sh`.
- Swift 6 toolchain in Swift 5 language mode (`Package.swift`). Classes touching AppKit are `@MainActor`; C callbacks
  and NSEvent monitors hop in with `MainActor.assumeIsolated`.

### Architecture

| File | Role |
| --- | --- |
| `main.swift` / `AppDelegate.swift` | Entry point, menu bar item and menu, editor window |
| `DragMonitor.swift` | Global mouse monitors; detects a window move (origin changes, size doesn't) |
| `ZoneEngine.swift` | Zone under the cursor, ⌃ spanning, snapping, keyboard navigation |
| `Overlay.swift` | Click-through overlay panel drawing the zones |
| `Accessibility.swift` | `AXWindow`: find, read and set window frames via the Accessibility API |
| `Screens.swift` | Coordinate conversion and stable display ids |
| `Models.swift` / `LayoutStore.swift` | Zones, layouts, templates, persisted `Config` |
| `EditorView.swift` | SwiftUI editor: screens, settings, layout canvas, gap control |
| `HotKeys.swift` | Carbon global hot keys |
| `LaunchAtLogin.swift` | Login item via `SMAppService` |

### Gotchas

- **Two coordinate systems.** Cocoa/`NSScreen` use a bottom-left origin; the Accessibility API uses top-left relative to
  the primary screen. Zone logic works in AX coordinates (`axFrame`, `axVisibleFrame`, `Geometry.mouseLocation`);
  convert with `Geometry.flip` only when positioning Cocoa windows.
- Zones are normalized (0…1, top-left origin). The gap is applied in `LayoutStore.zoneRect(_:in:spacing:)`: the screen
  is inset by gap/2, then each zone by gap/2, giving `gap` between zones and at the edges. `LayoutStore.zone(for:in:spacing:id:)`
  is its inverse (used by the px fields in the editor); keep the two in sync. The editor canvas mirrors the same math.
- Editor drag gestures must measure in the canvas's named coordinate space (`"canvas"`). Measuring relative to the view
  being dragged makes it jitter, because the view moves as it resizes.
- `LayoutStore` saves are debounced (`scheduleSave`), since dragging in the editor changes the config many times a second.
  Call `saveNow()` when a write must happen immediately.
- Template layouts are read-only and have fixed UUIDs; per-layout gaps are stored in `Config.layoutSpacing` so they
  work for templates too.
- Views that look up a layout by id must handle it being gone (deleting a layout re-renders before the selection changes).
- Settings live in `~/Library/Application Support/MacZones/config.json`; new `Config` fields must be decoded with
  `decodeIfPresent` so older files still load.
