import AppKit
import Combine

@MainActor
final class LayoutStore: ObservableObject {
    static let shared = LayoutStore()

    @Published var config: Config {
        didSet { save() }
    }

    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacZones", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Config.self, from: data) {
            config = decoded
        } else {
            config = Config()
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Layouts

    var allLayouts: [Layout] { LayoutTemplates.all + config.customLayouts }

    func layout(id: UUID) -> Layout? {
        allLayouts.first { $0.id == id }
    }

    func layout(for screen: NSScreen) -> Layout {
        config.screenLayouts[screen.stableID].flatMap(layout(id:)) ?? LayoutTemplates.defaultLayout
    }

    func assign(_ layoutID: UUID, to screen: NSScreen) {
        config.screenLayouts[screen.stableID] = layoutID
    }

    @discardableResult
    func addCustomLayout(basedOn source: Layout? = nil) -> Layout {
        let zones = (source?.zones ?? LayoutTemplates.twoColumns.zones).map { zone in
            var copy = zone
            copy.id = UUID()
            return copy
        }
        let name = source.map { "\($0.name) (kopi)" } ?? "Nyt layout"
        let layout = Layout(id: UUID(), name: name, zones: zones)
        config.customLayouts.append(layout)
        return layout
    }

    func update(_ layout: Layout) {
        guard !layout.isTemplate,
              let index = config.customLayouts.firstIndex(where: { $0.id == layout.id }) else { return }
        config.customLayouts[index] = layout
    }

    func deleteLayout(id: UUID) {
        config.customLayouts.removeAll { $0.id == id }
        config.screenLayouts = config.screenLayouts.filter { $0.value != id }
        config.layoutSpacing[id.uuidString] = nil
    }

    func spacing(for layoutID: UUID) -> Double {
        config.layoutSpacing[layoutID.uuidString] ?? config.spacing
    }

    /// Pass nil to fall back to the default gap.
    func setSpacing(_ spacing: Double?, for layoutID: UUID) {
        config.layoutSpacing[layoutID.uuidString] = spacing
    }

    // MARK: Geometry

    /// Zone rectangles for a screen in global Accessibility coordinates (top-left origin).
    func zoneRects(for screen: NSScreen) -> [CGRect] {
        let layout = layout(for: screen)
        let spacing = spacing(for: layout.id)
        let inner = screen.axVisibleFrame.insetBy(dx: spacing / 2, dy: spacing / 2)
        return layout.zones.map { zone in
            zone.rect(in: inner).insetBy(dx: spacing / 2, dy: spacing / 2).integral
        }
    }
}
