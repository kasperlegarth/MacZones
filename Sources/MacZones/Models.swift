import Foundation

/// A zone in normalized coordinates (0...1) with origin in the top-left corner.
struct Zone: Codable, Identifiable, Hashable {
    var id = UUID()
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    func rect(in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + x * frame.width,
            y: frame.minY + y * frame.height,
            width: width * frame.width,
            height: height * frame.height
        )
    }
}

struct Layout: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var zones: [Zone]
    var isTemplate: Bool = false
}

enum Activation: String, Codable, CaseIterable, Identifiable {
    case shift
    case always

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shift: "Hold ⇧ Shift nede mens du trækker"
        case .always: "Altid (hold ⇧ Shift for at slå fra)"
        }
    }
}

struct Config: Codable {
    var customLayouts: [Layout] = []
    /// Display UUID -> layout id.
    var screenLayouts: [String: UUID] = [:]
    /// Default gap in points between zones and around the screen edge.
    var spacing: Double = 8
    /// Per-layout gap overriding `spacing`, keyed by layout id.
    var layoutSpacing: [String: Double] = [:]
    var activation: Activation = .shift
    var hotkeysEnabled = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Config()
        customLayouts = try c.decodeIfPresent([Layout].self, forKey: .customLayouts) ?? defaults.customLayouts
        screenLayouts = try c.decodeIfPresent([String: UUID].self, forKey: .screenLayouts) ?? defaults.screenLayouts
        spacing = try c.decodeIfPresent(Double.self, forKey: .spacing) ?? defaults.spacing
        layoutSpacing = try c.decodeIfPresent([String: Double].self, forKey: .layoutSpacing) ?? defaults.layoutSpacing
        activation = try c.decodeIfPresent(Activation.self, forKey: .activation) ?? defaults.activation
        hotkeysEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeysEnabled) ?? defaults.hotkeysEnabled
    }
}

enum LayoutTemplates {
    static let focus = template("00000000-0000-0000-0000-000000000001", "Fokus", [
        Zone(x: 0.1, y: 0.05, width: 0.8, height: 0.9),
    ])
    static let twoColumns = template("00000000-0000-0000-0000-000000000002", "2 kolonner", columns([0.5, 0.5]))
    static let threeColumns = template("00000000-0000-0000-0000-000000000003", "3 kolonner", columns([1 / 3, 1 / 3, 1 / 3]))
    static let priority = template("00000000-0000-0000-0000-000000000004", "Prioritet", columns([0.25, 0.5, 0.25]))
    static let sixtyForty = template("00000000-0000-0000-0000-000000000005", "60 / 40", columns([0.6, 0.4]))
    static let rows = template("00000000-0000-0000-0000-000000000006", "2 rækker", [
        Zone(x: 0, y: 0, width: 1, height: 0.5),
        Zone(x: 0, y: 0.5, width: 1, height: 0.5),
    ])
    static let grid2x2 = template("00000000-0000-0000-0000-000000000007", "Gitter 2×2", grid(rows: 2, columns: 2))
    static let grid3x2 = template("00000000-0000-0000-0000-000000000008", "Gitter 3×2", grid(rows: 2, columns: 3))

    static let all = [priority, twoColumns, threeColumns, sixtyForty, rows, grid2x2, grid3x2, focus]
    static let defaultLayout = priority

    private static func template(_ id: String, _ name: String, _ zones: [Zone]) -> Layout {
        Layout(id: UUID(uuidString: id)!, name: name, zones: zones, isTemplate: true)
    }

    private static func columns(_ widths: [Double]) -> [Zone] {
        var x = 0.0
        return widths.map { w in
            defer { x += w }
            return Zone(x: x, y: 0, width: w, height: 1)
        }
    }

    private static func grid(rows: Int, columns: Int) -> [Zone] {
        (0..<rows).flatMap { r in
            (0..<columns).map { c in
                Zone(
                    x: Double(c) / Double(columns),
                    y: Double(r) / Double(rows),
                    width: 1 / Double(columns),
                    height: 1 / Double(rows)
                )
            }
        }
    }
}
