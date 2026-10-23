import Foundation
import SwiftData

/// The three tabs of zweef.app's own maintenance form: what an hour of work
/// can be booked on (ADR 0020).
enum MaterialKind: String, CaseIterable, Codable, Sendable {
    /// "Vliegend": aircraft. `material.json` `category` "kist".
    case flying = "kist"
    /// "Rollend": winches, golf carts, cars, trailers.
    case rolling = "rollend"
    /// "Overig": the club itself and its projects ("Club", "Overige projecten").
    case other = "overig"
}

/// One item of zweef.app's `material.json`: what the member picks when
/// stopping, exactly as in zweef.app's own form.
///
/// Stored locally so the picker works in a hangar without a connection;
/// `zweefId` is uploaded as `material_id` and `name` as `project`.
@Model
final class Material {
    #Unique<Material>([\.zweefId])

    var zweefId: Int
    var name: String
    /// `MaterialKind`, stored raw so a value zweef.app adds later decodes as
    /// "other" instead of failing.
    var kindRaw: String
    /// The make and model ("Schleicher ASK 21"), shown under the name. Empty
    /// when zweef.app has none.
    var typeName: String
    /// For aircraft: whether the club owns it (`kist_category` "club"), not a
    /// member. Only the club's aircraft are offered. Always true otherwise.
    var isClubOwned: Bool
    /// Gliders first among the aircraft: that is where most workshop hours go.
    var isGlider: Bool
    /// zweef.app's own ordering within a tab.
    var sortOrder: Int

    var kind: MaterialKind { MaterialKind(rawValue: kindRaw) ?? .other }

    /// Whether the stop sheet offers it: anything rolling or other, and the
    /// club's own aircraft.
    var isOffered: Bool { kind != .flying || isClubOwned }

    /// The type to show, or nil when there is none.
    var displayType: String? { typeName.isEmpty ? nil : typeName }

    init(
        zweefId: Int,
        name: String,
        kind: MaterialKind,
        typeName: String = "",
        isClubOwned: Bool = true,
        isGlider: Bool = false,
        sortOrder: Int = 0
    ) {
        self.zweefId = zweefId
        self.name = name
        self.kindRaw = kind.rawValue
        self.typeName = typeName
        self.isClubOwned = isClubOwned
        self.isGlider = isGlider
        self.sortOrder = sortOrder
    }
}

extension [Material] {
    /// The order the picker shows a tab in: gliders first among aircraft, then
    /// zweef.app's own order, then by name.
    func sortedForPicker() -> [Material] {
        sorted { lhs, rhs in
            if lhs.isGlider != rhs.isGlider { return lhs.isGlider }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
