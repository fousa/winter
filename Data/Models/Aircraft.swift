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
    /// Gliders are offered first, because glider maintenance is what most
    /// workshop hours are spent on.
    var isGlider: Bool

    init(zweefId: Int, name: String, registration: String? = nil, isGlider: Bool = true) {
        self.zweefId = zweefId
        self.name = name
        self.registration = registration
        self.isGlider = isGlider
    }
}
