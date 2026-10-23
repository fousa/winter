import Foundation
import SwiftData

/// An aircraft or piece of equipment, mirrored from zweef.app `material.json`.
///
/// Stored locally so the aircraft picker works in a hangar without a
/// connection; `zweefId` is what gets uploaded as `material_id`.
@Model
final class Aircraft {
    #Unique<Aircraft>([\.zweefId])

    var zweefId: Int
    var name: String
    var registration: String?
    /// The make and model from zweef.app ("Schleicher ASK 21"), shown under
    /// the name so a member who knows the type but not the registration finds
    /// the right one. Empty when zweef.app has none, nil when it has not been
    /// fetched yet; show ``displayType``.
    var typeName: String?
    /// Whether the club owns it rather than a member (`kist_category`). Nil
    /// until the first refresh that read it; only club aircraft are offered
    /// when stopping a timer.
    var isClubOwned: Bool?
    /// Gliders are offered first, because glider maintenance is what most
    /// workshop hours are spent on.
    var isGlider: Bool

    init(
        zweefId: Int,
        name: String,
        registration: String? = nil,
        typeName: String? = nil,
        isClubOwned: Bool? = true,
        isGlider: Bool = true
    ) {
        self.zweefId = zweefId
        self.name = name
        self.registration = registration
        self.typeName = typeName
        self.isClubOwned = isClubOwned
        self.isGlider = isGlider
    }
}
