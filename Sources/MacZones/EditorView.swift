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
    @State private var measureScreenID: String?

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

            let screen = measureScreen
            let spacing = store.spacing(for: layoutID)
            LayoutCanvas(
                layout: binding,
                selection: $selectedZone,
                editable: editable,
                spacing: spacing,
                screenSize: screen?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MeasureBar(
                layout: binding,
                editable: editable,
                selectedZone: selectedZone,
                screen: screen,
                spacing: spacing,
                screenID: Binding(get: { screen?.stableID }, set: { measureScreenID = $0 })
            )

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

    /// The screen whose size the measurements are shown for: the chosen one, else one using this layout, else the main screen.
    private var measureScreen: NSScreen? {
        let screens = NSScreen.screens
        return screens.first { $0.stableID == measureScreenID }
            ?? screens.first { store.layout(for: $0).id == layoutID }
            ?? NSScreen.main
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

// MARK: - Measurements

/// Which screen the zone sizes are measured on, and the exact frame of the selected zone.
private struct MeasureBar: View {
    @Binding var layout: Layout
    let editable: Bool
    let selectedZone: UUID?
    let screen: NSScreen?
    let spacing: Double
    @Binding var screenID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            screenRow
            if let screen, let index = layout.zones.firstIndex(where: { $0.id == selectedZone }) {
                // Fresh fields per zone, so an uncommitted value never lands on the next selected zone.
                zoneRow(index: index, screen: screen)
                    .id(selectedZone)
            }
        }
        .font(.callout)
    }

    private var screenRow: some View {
        HStack(spacing: 12) {
            Label("Mål", systemImage: "ruler")
            if NSScreen.screens.count > 1 {
                Picker("Skærm", selection: $screenID) {
                    ForEach(NSScreen.screens, id: \.stableID) { screen in
                        Text(screen.localizedName).tag(Optional(screen.stableID))
                    }
                }
                .labelsHidden()
                .fixedSize()
            } else if let screen {
                Text(screen.localizedName)
            }
            if let screen {
                Text("Arbejdsområde \(Int(screen.visibleFrame.width)) × \(Int(screen.visibleFrame.height)) px")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func zoneRow(index: Int, screen: NSScreen) -> some View {
        let frame = CGRect(origin: .zero, size: screen.visibleFrame.size)
        let rect = LayoutStore.zoneRect(layout.zones[index], in: frame, spacing: spacing)

        return HStack(spacing: 14) {
            Text("Zone \(index + 1)").fontWeight(.semibold)
            PixelField(title: "X", value: Int(rect.minX), editable: editable, onCommit: setEdge(index, frame) { $0.origin.x = $1 })
            PixelField(title: "Y", value: Int(rect.minY), editable: editable, onCommit: setEdge(index, frame) { $0.origin.y = $1 })
            PixelField(title: "Bredde", value: Int(rect.width), editable: editable, onCommit: setEdge(index, frame) { $0.size.width = $1 })
            PixelField(title: "Højde", value: Int(rect.height), editable: editable, onCommit: setEdge(index, frame) { $0.size.height = $1 })
            Text("px").foregroundStyle(.secondary)
            Spacer()
        }
    }

    /// Returns a setter that applies a typed pixel value to one component of the zone's rect.
    private func setEdge(_ index: Int, _ frame: CGRect, _ apply: @escaping (inout CGRect, CGFloat) -> Void) -> (Int) -> Void {
        { value in
            var rect = LayoutStore.zoneRect(layout.zones[index], in: frame, spacing: spacing)
            apply(&rect, CGFloat(value))

            // Keep the zone on screen and at least 40 px in each direction.
            let minSize: CGFloat = 40
            rect.size.width = min(max(rect.width, minSize), frame.width - 2 * spacing)
            rect.size.height = min(max(rect.height, minSize), frame.height - 2 * spacing)
            rect.origin.x = min(max(rect.minX, spacing), frame.width - spacing - rect.width)
            rect.origin.y = min(max(rect.minY, spacing), frame.height - spacing - rect.height)

            layout.zones[index] = LayoutStore.zone(for: rect, in: frame, spacing: spacing, id: layout.zones[index].id)
        }
    }
}

/// A labelled number field for one pixel value; commits on Return or when focus leaves.
private struct PixelField: View {
    let title: String
    let value: Int
    let editable: Bool
    let onCommit: (Int) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title).foregroundStyle(.secondary)
            if editable {
                TextField(title, text: $text)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 64)
                    .focused($focused)
                    .onSubmit(commit)
                    .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                    .onChange(of: value) { _, newValue in if !focused { text = String(newValue) } }
                    .onAppear { text = String(value) }
            } else {
                Text("\(value)").monospacedDigit()
            }
        }
    }

    private func commit() {
        guard let number = Int(text.trimmingCharacters(in: .whitespaces)), number != value else {
            text = String(value)
            return
        }
        onCommit(number)
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
    /// Usable area of the screen the layout is measured on.
    let screenSize: CGSize

    @State private var moveOrigin: Zone?
    @State private var resizeOrigin: Zone?
    /// Zones and edge position captured when dragging a shared edge starts.
    @State private var edgeDragOrigin: (zones: [UUID: Zone], position: Double)?

    /// Smallest zone size, as a fraction of the screen.
    private let minSize = 0.03
    /// How close (in canvas points) an edge must get to another edge before it snaps to it.
    private let magnet: CGFloat = 6
    /// How far (in canvas points) an edge must be pushed past a neighbouring zone's edge before it overlaps it.
    private let resistance: CGFloat = 28
    private let space = "canvas"

    private var aspectRatio: CGFloat {
        screenSize.height > 0 ? screenSize.width / screenSize.height : 16 / 10
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
                if editable {
                    ForEach(sharedEdges()) { edge in
                        edgeHandle(edge, size: size)
                    }
                }
            }
            // Gestures measure in this fixed space; measuring relative to the moving zone makes resizing jitter.
            .coordinateSpace(name: space)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    /// The gap scaled down to the canvas.
    private func canvasGap(_ size: CGSize) -> CGFloat {
        max(spacing * size.width / max(screenSize.width, 1), 1)
    }

    private func zoneView(index: Int, zone: Zone, size: CGSize) -> some View {
        let gap = canvasGap(size)
        let inner = CGRect(origin: .zero, size: size).insetBy(dx: gap / 2, dy: gap / 2)
        let rect = zone.rect(in: inner).insetBy(dx: gap / 2, dy: gap / 2)
        let selected = selection == zone.id
        let real = LayoutStore.zoneRect(zone, in: CGRect(origin: .zero, size: screenSize), spacing: spacing)

        return ZoneTile(number: index + 1, selected: selected, dimensions: "\(Int(real.width)) × \(Int(real.height))")
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .overlay(alignment: .bottomTrailing) {
                if editable && selected {
                    Circle()
                        .fill(Color.accentColor)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .frame(width: 14, height: 14)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .gesture(resizeGesture(zone: zone, size: size))
                }
            }
            .offset(x: rect.minX, y: rect.minY)
            .onTapGesture { selection = zone.id }
            .gesture(moveGesture(zone: zone, size: size), including: editable ? .all : .subviews)
    }

    private func moveGesture(zone: Zone, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(space))
            .onChanged { value in
                if moveOrigin == nil {
                    moveOrigin = zone
                    selection = zone.id
                }
                guard let origin = moveOrigin else { return }
                let dx = value.translation.width / size.width
                let dy = value.translation.height / size.height
                // Neighbours are judged at the zone's raw new position on the other axis.
                var atRawY = origin
                atRawY.y += dy
                var atRawX = origin
                atRawX.x += dx

                var updated = origin
                updated.x = movedStart(origin.x, length: origin.width, by: dx, neighbours: neighbours(of: atRawY, alongX: true),
                                       start: \.x, length: \.width, except: zone.id, scale: size.width)
                updated.y = movedStart(origin.y, length: origin.height, by: dy, neighbours: neighbours(of: atRawX, alongX: false),
                                       start: \.y, length: \.height, except: zone.id, scale: size.height)
                replace(updated)
            }
            .onEnded { _ in moveOrigin = nil }
    }

    private func resizeGesture(zone: Zone, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(space))
            .onChanged { value in
                if resizeOrigin == nil { resizeOrigin = zone }
                guard let origin = resizeOrigin else { return }
                let fromX = origin.x + origin.width
                let fromY = origin.y + origin.height
                let maxX = leadingEdge(
                    from: fromX, to: fromX + value.translation.width / size.width,
                    neighbours: neighbours(of: origin, alongX: true), start: \.x, length: \.width, scale: size.width
                ) ?? snap(fromX + value.translation.width / size.width, to: edges(\.x, \.width, except: zone.id), scale: size.width)
                let maxY = leadingEdge(
                    from: fromY, to: fromY + value.translation.height / size.height,
                    neighbours: neighbours(of: origin, alongX: false), start: \.y, length: \.height, scale: size.height
                ) ?? snap(fromY + value.translation.height / size.height, to: edges(\.y, \.height, except: zone.id), scale: size.height)

                var updated = origin
                updated.width = (maxX - origin.x).clamped(minSize, 1 - origin.x)
                updated.height = (maxY - origin.y).clamped(minSize, 1 - origin.y)
                replace(updated)
            }
            .onEnded { _ in resizeOrigin = nil }
    }

    private func replace(_ zone: Zone) {
        guard let index = layout.zones.firstIndex(where: { $0.id == zone.id }) else { return }
        layout.zones[index] = zone
    }

    /// Screen edges, the middle, and both edges of every other zone along one axis.
    private func edges(_ start: KeyPath<Zone, Double>, _ length: KeyPath<Zone, Double>, except id: UUID) -> [Double] {
        [0, 0.5, 1] + layout.zones.filter { $0.id != id }.flatMap { [$0[keyPath: start], $0[keyPath: start] + $0[keyPath: length]] }
    }

    /// Snaps a single edge to the nearest candidate edge within the magnet distance.
    private func snap(_ value: Double, to edges: [Double], scale: CGFloat) -> Double {
        guard let nearest = edges.min(by: { abs($0 - value) < abs($1 - value) }),
              abs(nearest - value) * scale <= magnet else { return value }
        return nearest
    }

    // MARK: Shared edges

    /// Draggable line where zones touch: `before` zones end at `position`, `after` zones start there.
    private func sharedEdges() -> [SharedEdge] {
        sharedEdges(vertical: true) + sharedEdges(vertical: false)
    }

    private func sharedEdges(vertical: Bool) -> [SharedEdge] {
        let start: KeyPath<Zone, Double> = vertical ? \.x : \.y
        let length: KeyPath<Zone, Double> = vertical ? \.width : \.height
        let crossStart: KeyPath<Zone, Double> = vertical ? \.y : \.x
        let crossLength: KeyPath<Zone, Double> = vertical ? \.height : \.width
        let tolerance = 0.002

        func end(_ zone: Zone) -> Double { zone[keyPath: start] + zone[keyPath: length] }
        func crossRange(_ zone: Zone) -> ClosedRange<Double> {
            zone[keyPath: crossStart]...(zone[keyPath: crossStart] + zone[keyPath: crossLength])
        }

        var positions: [Double] = []
        for zone in layout.zones where end(zone) > tolerance && end(zone) < 1 - tolerance {
            if !positions.contains(where: { abs($0 - end(zone)) < tolerance }) { positions.append(end(zone)) }
        }

        var result: [SharedEdge] = []
        for position in positions {
            let before = layout.zones.filter { abs(end($0) - position) < tolerance }
            let after = layout.zones.filter { abs($0[keyPath: start] - position) < tolerance }

            // Touching pairs (overlapping across the edge), grouped into connected runs along the edge.
            var pairs: [(Zone, Zone, ClosedRange<Double>)] = []
            for b in before {
                for a in after {
                    let lower = max(crossRange(b).lowerBound, crossRange(a).lowerBound)
                    let upper = min(crossRange(b).upperBound, crossRange(a).upperBound)
                    if upper - lower > tolerance { pairs.append((b, a, lower...upper)) }
                }
            }
            var groups: [[(Zone, Zone, ClosedRange<Double>)]] = []
            for pair in pairs {
                let ids: Set<UUID> = [pair.0.id, pair.1.id]
                let matching = groups.indices.filter { i in groups[i].contains { ids.contains($0.0.id) || ids.contains($0.1.id) } }
                var merged = matching.flatMap { groups[$0] } + [pair]
                for i in matching.reversed() { groups.remove(at: i) }
                merged.sort { $0.2.lowerBound < $1.2.lowerBound }
                groups.append(merged)
            }

            for group in groups {
                let beforeIDs = Array(Set(group.map(\.0.id)))
                let afterIDs = Array(Set(group.map(\.1.id)))
                let span = group.map(\.2.lowerBound).min()!...group.map(\.2.upperBound).max()!
                let id = (vertical ? "v" : "h") + (beforeIDs + afterIDs).map(\.uuidString).sorted().joined()
                result.append(SharedEdge(id: id, vertical: vertical, position: position, span: span, before: beforeIDs, after: afterIDs))
            }
        }
        return result
    }

    private func edgeHandle(_ edge: SharedEdge, size: CGSize) -> some View {
        let gap = canvasGap(size)
        let inner = CGRect(origin: .zero, size: size).insetBy(dx: gap / 2, dy: gap / 2)
        let thickness = max(gap + 6, 12)
        // Leave the ends free so the corner resize handles stay reachable.
        let endInset: CGFloat = 18
        let frame: CGRect
        if edge.vertical {
            let x = inner.minX + edge.position * inner.width
            let y0 = inner.minY + edge.span.lowerBound * inner.height + endInset
            let y1 = inner.minY + edge.span.upperBound * inner.height - endInset
            frame = CGRect(x: x - thickness / 2, y: y0, width: thickness, height: max(y1 - y0, 8))
        } else {
            let y = inner.minY + edge.position * inner.height
            let x0 = inner.minX + edge.span.lowerBound * inner.width + endInset
            let x1 = inner.minX + edge.span.upperBound * inner.width - endInset
            frame = CGRect(x: x0, y: y - thickness / 2, width: max(x1 - x0, 8), height: thickness)
        }

        let dragging = edge.before.contains { edgeDragOrigin?.zones[$0] != nil }
        return EdgeHandle(vertical: edge.vertical, dragging: dragging)
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .gesture(edgeGesture(edge, size: size))
    }

    private func edgeGesture(_ edge: SharedEdge, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(space))
            .onChanged { value in
                if edgeDragOrigin == nil {
                    let ids = Set(edge.before + edge.after)
                    let zones = Dictionary(uniqueKeysWithValues: layout.zones.filter { ids.contains($0.id) }.map { ($0.id, $0) })
                    edgeDragOrigin = (zones, edge.position)
                }
                guard let origin = edgeDragOrigin else { return }

                let start: WritableKeyPath<Zone, Double> = edge.vertical ? \.x : \.y
                let length: WritableKeyPath<Zone, Double> = edge.vertical ? \.width : \.height
                let scale = edge.vertical ? size.width : size.height
                let delta = (edge.vertical ? value.translation.width : value.translation.height) / scale

                // Snap to other zones' edges, and keep every zone on both sides at least `minSize`.
                let others = layout.zones.filter { origin.zones[$0.id] == nil }
                    .flatMap { [$0[keyPath: start], $0[keyPath: start] + $0[keyPath: length]] }
                var position = snap(origin.position + delta, to: [0.5] + others, scale: scale)
                let lower = edge.before.compactMap { origin.zones[$0] }.map { $0[keyPath: start] + minSize }.max() ?? 0
                let upper = edge.after.compactMap { origin.zones[$0] }.map { $0[keyPath: start] + $0[keyPath: length] - minSize }.min() ?? 1
                position = position.clamped(lower, upper)

                var zones = layout.zones
                for index in zones.indices {
                    guard let original = origin.zones[zones[index].id] else { continue }
                    if edge.before.contains(original.id) {
                        zones[index][keyPath: length] = position - original[keyPath: start]
                    } else {
                        zones[index][keyPath: start] = position
                        zones[index][keyPath: length] = original[keyPath: start] + original[keyPath: length] - position
                    }
                }
                layout.zones = zones
            }
            .onEnded { _ in edgeDragOrigin = nil }
    }

    /// Zones that lie beside `zone` along an axis, i.e. overlap it on the other axis, so they can be bumped into.
    private func neighbours(of zone: Zone, alongX: Bool) -> [Zone] {
        func overlaps(_ a: Double, _ aLength: Double, _ b: Double, _ bLength: Double) -> Bool {
            a < b + bLength - 0.001 && b < a + aLength - 0.001
        }
        return layout.zones.filter { other in
            other.id != zone.id && (alongX
                ? overlaps(zone.y, zone.height, other.y, other.height)
                : overlaps(zone.x, zone.width, other.x, other.width))
        }
    }

    /// Where a leading edge dragged from `from` to `to` stops because it ran into a neighbouring zone,
    /// or nil if it didn't. The edge sticks to the neighbour's edge until pushed `resistance` points past it.
    private func leadingEdge(
        from: Double, to: Double, neighbours: [Zone],
        start: KeyPath<Zone, Double>, length: KeyPath<Zone, Double>, scale: CGFloat
    ) -> Double? {
        let increasing = to > from
        // Moving forward the edge enters a neighbour at its start; moving back, at its end.
        let barriers = neighbours
            .map { increasing ? $0[keyPath: start] : $0[keyPath: start] + $0[keyPath: length] }
            .filter { increasing ? ($0 >= from - 1e-6 && $0 < to) : ($0 <= from + 1e-6 && $0 > to) }
            .sorted { abs($0 - from) < abs($1 - from) }
        return barriers.first { abs(to - $0) * scale < resistance }
    }

    /// New start of a zone moved by `delta`: its leading edge resists neighbours, otherwise either edge snaps magnetically.
    private func movedStart(
        _ origin: Double, length: Double, by delta: Double, neighbours: [Zone],
        start: KeyPath<Zone, Double>, length lengthPath: KeyPath<Zone, Double>, except id: UUID, scale: CGFloat
    ) -> Double {
        let raw = origin + delta
        let lead = delta >= 0 ? origin + length : origin
        if let stop = leadingEdge(from: lead, to: lead + delta, neighbours: neighbours, start: start, length: lengthPath, scale: scale) {
            return (delta >= 0 ? stop - length : stop).clamped(0, 1 - length)
        }
        return snapMove(raw.clamped(0, 1 - length), length: length, edges: edges(start, lengthPath, except: id), scale: scale)
    }

    /// Snaps a moving zone by whichever of its two edges is closest to a candidate edge.
    private func snapMove(_ start: Double, length: Double, edges: [Double], scale: CGFloat) -> Double {
        let startDelta = snap(start, to: edges, scale: scale) - start
        let endDelta = snap(start + length, to: edges, scale: scale) - (start + length)
        let deltas = [startDelta, endDelta].filter { $0 != 0 }
        let delta = deltas.min { abs($0) < abs($1) } ?? 0
        return (start + delta).clamped(0, 1 - length)
    }
}

private struct SharedEdge: Identifiable {
    /// Built from the zone ids, so it stays stable while the edge is being dragged.
    let id: String
    /// A vertical line between zones side by side (dragged horizontally).
    let vertical: Bool
    let position: Double
    /// Extent along the line where the zones touch.
    let span: ClosedRange<Double>
    let before: [UUID]
    let after: [UUID]
}

/// Invisible grab area on a shared edge; shows a bar and a resize cursor on hover.
private struct EdgeHandle: View {
    let vertical: Bool
    let dragging: Bool
    @State private var hovering = false

    var body: some View {
        ZStack {
            Color.clear.contentShape(Rectangle())
            if hovering || dragging {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: vertical ? 4 : nil, height: vertical ? nil : 4)
                    .frame(maxWidth: vertical ? 4 : 60, maxHeight: vertical ? 60 : 4)
                    .shadow(color: .black.opacity(0.25), radius: 2)
            }
        }
        .onHover { inside in
            hovering = inside
            if inside {
                (vertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
            } else {
                NSCursor.pop()
            }
        }
        // Don't leave the resize cursor stuck if the handle vanishes under the mouse (e.g. a zone is deleted).
        .onDisappear { if hovering { NSCursor.pop() } }
    }
}

private struct ZoneTile: View {
    let number: Int
    let selected: Bool
    /// Real size in px, e.g. "860 × 1080".
    let dimensions: String

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.accentColor.opacity(selected ? 0.35 : 0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(selected ? 1 : 0.5), lineWidth: selected ? 2.5 : 1)
            )
            .overlay(
                VStack(spacing: 2) {
                    Text("\(number)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text(dimensions)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .padding(4)
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
                                Text("\(index + 1)").font(.caption.weight(.bold)).foregroundStyle(.primary)
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
