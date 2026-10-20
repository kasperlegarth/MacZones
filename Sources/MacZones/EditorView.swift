import AppKit
import SwiftUI

enum SidebarItem: Hashable {
    case layout(UUID)
    case screens
    case settings
}

struct EditorView: View {
    @EnvironmentObject private var store: LayoutStore
    @State private var selection: SidebarItem? = .screens

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label("Skærme", systemImage: "display.2").tag(SidebarItem.screens)
                    Label("Indstillinger", systemImage: "gearshape").tag(SidebarItem.settings)
                }
                Section("Skabeloner") {
                    ForEach(LayoutTemplates.all) { layout in
                        LayoutRow(layout: layout).tag(SidebarItem.layout(layout.id))
                    }
                }
                Section("Mine layouts") {
                    ForEach(store.config.customLayouts) { layout in
                        LayoutRow(layout: layout).tag(SidebarItem.layout(layout.id))
                    }
                    Button {
                        selection = .layout(store.addCustomLayout().id)
                    } label: {
                        Label("Nyt layout", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            switch selection {
            case .layout(let id) where store.layout(id: id) != nil:
                LayoutDetail(layoutID: id, selection: $selection)
            case .settings:
                SettingsView()
            default:
                ScreensView()
            }
        }
    }
}

private struct LayoutRow: View {
    let layout: Layout

    var body: some View {
        HStack(spacing: 10) {
            LayoutThumbnail(layout: layout)
                .frame(width: 36, height: 22)
            Text(layout.name)
        }
    }
}

// MARK: - Screens

private struct ScreensView: View {
    @EnvironmentObject private var store: LayoutStore

    var body: some View {
        Form {
            ForEach(NSScreen.screens, id: \.stableID) { screen in
                Section(screen.localizedName) {
                    Picker("Layout", selection: binding(for: screen)) {
                        ForEach(store.allLayouts) { layout in
                            Text(layout.name).tag(layout.id)
                        }
                    }
                    LayoutThumbnail(layout: store.layout(for: screen), showNumbers: true)
                        .aspectRatio(screen.frame.width / screen.frame.height, contentMode: .fit)
                        .frame(maxHeight: 180)
                    Text("\(Int(screen.frame.width)) × \(Int(screen.frame.height)) pt")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Skærme")
    }

    private func binding(for screen: NSScreen) -> Binding<UUID> {
        Binding(
            get: { store.layout(for: screen).id },
            set: { store.assign($0, to: screen) }
        )
    }
}

// MARK: - Settings

private struct SettingsView: View {
    @EnvironmentObject private var store: LayoutStore
    @State private var trusted = Permissions.isTrusted
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginNeedsApproval = LaunchAtLogin.requiresApproval

    var body: some View {
        Form {
            Section("Generelt") {
                Toggle("Start MacZones ved login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLogin.setEnabled(enabled)
                        refreshLoginStatus()
                    }
                if loginNeedsApproval {
                    HStack {
                        Text("Skal godkendes under Login-emner.").foregroundStyle(.secondary)
                        Button("Åbn Systemindstillinger") { LaunchAtLogin.openSystemSettings() }
                    }
                }
            }
            Section("Træk og slip") {
                Picker("Vis zoner", selection: $store.config.activation) {
                    ForEach(Activation.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Standardgab mellem zoner") {
                    HStack {
                        Slider(value: $store.config.spacing, in: 0...32, step: 1)
                        Text("\(Int(store.config.spacing)) pt").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
                Text("Gabbet kan også sættes for hvert layout i editoren. Hold ⌃ Control nede under trækket for at strække vinduet over flere zoner.")
                    .foregroundStyle(.secondary)
            }
            Section("Tastaturgenveje") {
                Toggle("Aktivér genveje", isOn: $store.config.hotkeysEnabled)
                LabeledContent("Næste / forrige zone", value: "⌃⌥→  /  ⌃⌥←")
                LabeledContent("Flyt til zone 1–9", value: "⌃⌥1 … ⌃⌥9")
            }
            Section("Tilladelser") {
                LabeledContent("Tilgængelighed") {
                    if trusted {
                        Label("Givet", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Åbn Systemindstillinger") { Permissions.openSystemSettings() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Indstillinger")
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            trusted = Permissions.isTrusted
            loginNeedsApproval = LaunchAtLogin.requiresApproval
        }
    }
}

private extension SettingsView {
    func refreshLoginStatus() {
        launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.requiresApproval
        loginNeedsApproval = LaunchAtLogin.requiresApproval
    }
}

// MARK: - Layout detail

private struct LayoutDetail: View {
    @EnvironmentObject private var store: LayoutStore
    let layoutID: UUID
    @Binding var selection: SidebarItem?
    @State private var selectedZone: UUID?

    var body: some View {
        // The layout can disappear (e.g. right after deleting it) before the selection changes.
        if let layout = store.layout(id: layoutID) {
            content(layout)
        } else {
            Text("Vælg et layout").foregroundStyle(.secondary)
        }
    }

    private func content(_ layout: Layout) -> some View {
        let editable = !layout.isTemplate

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                if editable {
                    TextField("Navn", text: binding.name)
                        .textFieldStyle(.plain)
                        .font(.title2.weight(.semibold))
                } else {
                    Text(layout.name).font(.title2.weight(.semibold))
                }
                Spacer()
                Menu("Brug på skærm") {
                    ForEach(NSScreen.screens, id: \.stableID) { screen in
                        Button(screen.localizedName) { store.assign(layoutID, to: screen) }
                    }
                }
                .fixedSize()
            }

            LayoutCanvas(layout: binding, selection: $selectedZone, editable: editable, spacing: store.spacing(for: layoutID))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            GapControl(layoutID: layoutID)

            HStack {
                if editable {
                    Button { addZone() } label: { Label("Tilføj zone", systemImage: "plus.rectangle") }
                    Button { split(vertical: true) } label: { Label("Del lodret", systemImage: "rectangle.split.2x1") }
                        .disabled(selectedZone == nil)
                    Button { split(vertical: false) } label: { Label("Del vandret", systemImage: "rectangle.split.1x2") }
                        .disabled(selectedZone == nil)
                    Button(role: .destructive) { deleteZone() } label: { Label("Slet zone", systemImage: "trash") }
                        .disabled(selectedZone == nil)
                        .keyboardShortcut(.delete, modifiers: [])
                    Spacer()
                    Button("Slet layout", role: .destructive) {
                        selection = .screens
                        store.deleteLayout(id: layoutID)
                    }
                } else {
                    Text("Zonerne i en skabelon kan ikke redigeres.").foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        selection = .layout(store.addCustomLayout(basedOn: layout).id)
                    } label: {
                        Label("Duplikér og tilpas", systemImage: "plus.square.on.square")
                    }
                }
            }
        }
        .padding(20)
        .navigationTitle(layout.name)
        .onChange(of: layoutID) { selectedZone = nil }
    }

    private var binding: Binding<Layout> {
        Binding(
            get: { store.layout(id: layoutID) ?? LayoutTemplates.defaultLayout },
            set: { store.update($0) }
        )
    }

    private func addZone() {
        let zone = Zone(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
        binding.wrappedValue.zones.append(zone)
        selectedZone = zone.id
    }

    private func deleteZone() {
        binding.wrappedValue.zones.removeAll { $0.id == selectedZone }
        selectedZone = nil
    }

    private func split(vertical: Bool) {
        var layout = binding.wrappedValue
        guard let index = layout.zones.firstIndex(where: { $0.id == selectedZone }) else { return }
        var first = layout.zones[index]
        var second = first
        second.id = UUID()
        if vertical {
            first.width /= 2
            second.width = first.width
            second.x = first.x + first.width
        } else {
            first.height /= 2
            second.height = first.height
            second.y = first.y + first.height
        }
        layout.zones[index] = first
        layout.zones.insert(second, at: index + 1)
        binding.wrappedValue = layout
    }
}

// MARK: - Gap

/// Fixed gap between zones (and around the screen edge) for one layout.
private struct GapControl: View {
    @EnvironmentObject private var store: LayoutStore
    let layoutID: UUID

    var body: some View {
        let hasOverride = store.config.layoutSpacing[layoutID.uuidString] != nil

        HStack(spacing: 12) {
            Label("Gab mellem zoner", systemImage: "square.split.2x2")
            Slider(value: spacing, in: 0...48, step: 1)
                .frame(maxWidth: 260)
            Text("\(Int(store.spacing(for: layoutID))) pt")
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
            if hasOverride {
                Button("Brug standard (\(Int(store.config.spacing)) pt)") { store.setSpacing(nil, for: layoutID) }
                    .buttonStyle(.link)
            } else {
                Text("Standard").foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var spacing: Binding<Double> {
        Binding(
            get: { store.spacing(for: layoutID) },
            set: { store.setSpacing($0, for: layoutID) }
        )
    }
}

// MARK: - Canvas

private struct LayoutCanvas: View {
    @Binding var layout: Layout
    @Binding var selection: UUID?
    let editable: Bool
    /// Gap in points on the real screen.
    let spacing: Double

    @State private var moveOrigin: Zone?
    @State private var resizeOrigin: Zone?

    private let grid = 1.0 / 40

    private var aspectRatio: CGFloat {
        guard let frame = NSScreen.main?.frame, frame.height > 0 else { return 16 / 10 }
        return frame.width / frame.height
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .underPageBackgroundColor))
                    .onTapGesture { selection = nil }
                ForEach(Array(layout.zones.enumerated()), id: \.element.id) { index, zone in
                    zoneView(index: index, zone: zone, size: size)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private func zoneView(index: Int, zone: Zone, size: CGSize) -> some View {
        let screenWidth = NSScreen.main?.frame.width ?? 1440
        let gap = max(spacing * size.width / screenWidth, 1)
        let inner = CGRect(origin: .zero, size: size).insetBy(dx: gap / 2, dy: gap / 2)
        let rect = zone.rect(in: inner).insetBy(dx: gap / 2, dy: gap / 2)
        let selected = selection == zone.id

        return ZoneTile(number: index + 1, selected: selected)
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .overlay(alignment: .bottomTrailing) {
                if editable && selected {
                    Circle()
                        .fill(Color.accentColor)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .frame(width: 14, height: 14)
                        .padding(4)
                        .gesture(resizeGesture(zone: zone, size: size))
                }
            }
            .offset(x: rect.minX, y: rect.minY)
            .onTapGesture { selection = zone.id }
            .gesture(moveGesture(zone: zone, size: size), including: editable ? .all : .subviews)
    }

    private func moveGesture(zone: Zone, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if moveOrigin == nil {
                    moveOrigin = zone
                    selection = zone.id
                }
                guard let origin = moveOrigin else { return }
                var updated = origin
                updated.x = snap(origin.x + value.translation.width / size.width).clamped(0, 1 - origin.width)
                updated.y = snap(origin.y + value.translation.height / size.height).clamped(0, 1 - origin.height)
                replace(updated)
            }
            .onEnded { _ in moveOrigin = nil }
    }

    private func resizeGesture(zone: Zone, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if resizeOrigin == nil { resizeOrigin = zone }
                guard let origin = resizeOrigin else { return }
                var updated = origin
                updated.width = snap(origin.width + value.translation.width / size.width).clamped(grid * 2, 1 - origin.x)
                updated.height = snap(origin.height + value.translation.height / size.height).clamped(grid * 2, 1 - origin.y)
                replace(updated)
            }
            .onEnded { _ in resizeOrigin = nil }
    }

    private func replace(_ zone: Zone) {
        guard let index = layout.zones.firstIndex(where: { $0.id == zone.id }) else { return }
        layout.zones[index] = zone
    }

    private func snap(_ value: Double) -> Double {
        (value / grid).rounded() * grid
    }
}

private struct ZoneTile: View {
    let number: Int
    let selected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.accentColor.opacity(selected ? 0.35 : 0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(selected ? 1 : 0.5), lineWidth: selected ? 2.5 : 1)
            )
            .overlay(
                Text("\(number)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .minimumScaleFactor(0.3)
            )
            .contentShape(Rectangle())
    }
}

struct LayoutThumbnail: View {
    let layout: Layout
    var showNumbers = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15))
                ForEach(Array(layout.zones.enumerated()), id: \.element.id) { index, zone in
                    let rect = zone.rect(in: CGRect(origin: .zero, size: geo.size)).insetBy(dx: 1, dy: 1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.35))
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 0.75))
                        .overlay {
                            if showNumbers {
                                Text("\(index + 1)").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
        }
    }
}

private extension Double {
    func clamped(_ lower: Double, _ upper: Double) -> Double {
        Swift.min(Swift.max(self, lower), Swift.max(lower, upper))
    }
}
