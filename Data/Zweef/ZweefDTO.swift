import Foundation

/// The pieces of zweef.app's JSON the app actually uses.
///
/// Every shape here was read off live responses in October 2026, because the
/// published documentation has no response examples (`docs/zweef-api.md`). The
/// responses carry far more than this — an account alone has about sixty keys,
/// including medical and address data — and decoding only these four or five
/// fields is deliberate: what the app never decodes, it can never store, log or
/// leak.

/// A club member, from `GET /accounts.json`.
///
/// There is no photo: the endpoint returns no photo, avatar or image field for
/// any member, which is why the member tiles show initials.
struct ZweefAccount: Decodable, Equatable, Sendable {
    let id: Int
    let firstName: String
    let lastName: String
    let isActive: Bool
}

/// An aircraft or piece of equipment, from `GET /material.json`.
///
/// `id` is what `material_id` on a registration refers to — not `kistId`, which
/// links to the flights table and is null for anything that does not fly.
struct ZweefMaterial: Decodable, Equatable, Sendable {
    let id: Int
    let name: String
    /// "kist" (aircraft), "rollend" (rolling stock) or "overig" (other).
    let category: String
    /// "Glider", "TMG", "Sustainer", "Self-launching", or absent for anything
    /// that is not an aircraft. Absent *and* empty both occur.
    let kistConfiguration: String?
    /// "in bedrijf" or "niet inzetbaar".
    let status: String
    let isVisible: Bool

    /// Whether this is an aircraft rather than a winch, a car or a building.
    var isAircraft: Bool { category == "kist" }

    /// Whether it is an unpowered glider, which is what most workshop hours go
    /// into.
    var isGlider: Bool { kistConfiguration == "Glider" }
}

/// A maintenance-hour registration as zweef.app stores it, from
/// `GET /maintenance-hours/{period|current}/hours.json`.
///
/// Also how the app finds the active period: `periods.json` returns 404 for at
/// least one real club, so `periodId` here is the fallback (see
/// `docs/zweef-api.md`).
struct ZweefMaintenanceHour: Decodable, Equatable, Sendable {
    let id: Int
    let periodId: Int
    let userId: Int
    let date: String
    let hours: Double
    let materialId: Int?
    /// "in_aanvraag" when it still needs the board, "geaccepteerd" once
    /// approved. Both occur in real data.
    let status: String
    /// Carries the dedup tag the app put there, so an upload that timed out can
    /// be recognised instead of sent twice.
    let description: String
}

/// Club details, from `GET /club.json`.
///
/// Decoded tolerantly because this endpoint is the least dependable of the set:
/// it answered 500 for a real club. The app treats a missing club name as
/// "unknown" and shows "Winter" instead of failing.
struct ZweefClub: Decodable, Equatable, Sendable {
    let name: String?
}

/// What the app sends to `POST /maintenance-hours.json`.
///
/// Field names and defaults come from live data rather than the documentation's
/// example, which differs: real registrations carry an empty `category`, not
/// "Maintenance".
struct MaintenanceHourDraft: Encodable, Equatable, Sendable {
    var periodId: Int
    var userId: Int
    var userName: String
    /// `yyyy-MM-dd` in the device's own time zone, which is what defines the
    /// club's day.
    var date: String
    /// Decimal hours, two decimals (2 h 15 m → 2.25).
    var hours: Double
    var materialId: Int?
    var workorderId: Int?
    var isPrivate: Bool
    var category: String
    var subCategory: String
    /// The club's task label.
    var project: String
    /// Times, task, aircraft and flags, plus the dedup tag.
    var description: String
    /// `in_aanvraag`: everything arrives pending, and the board approves it in
    /// zweef.app (ADR 0004).
    var status: String
}

/// What comes back from a successful `POST /maintenance-hours.json`.
///
/// The shape is unconfirmed — posting to a live club to find out would create a
/// real registration — so the id is optional and every plausible shape is
/// accepted. A nil id is not a failure: dedup works off the tag in the
/// description, not off this.
struct CreatedRegistration: Decodable, Equatable, Sendable {
    let id: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case data
        case maintenanceHour
    }

    private struct Wrapper: Decodable { let id: Int? }

    init(from decoder: any Decoder) throws {
        // A bare id, `{"id": 12}`, `{"data": {"id": 12}}` or
        // `{"maintenance_hour": {"id": 12}}` all mean the same thing.
        if let single = try? decoder.singleValueContainer(), let id = try? single.decode(Int.self) {
            self.id = id
            return
        }

        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.id = nil
            return
        }

        if let id = try? container.decodeIfPresent(Int.self, forKey: .id) {
            self.id = id
        } else if let nested = try? container.decodeIfPresent(Wrapper.self, forKey: .data) {
            self.id = nested.id
        } else if let nested = try? container.decodeIfPresent(Wrapper.self, forKey: .maintenanceHour) {
            self.id = nested.id
        } else {
            self.id = nil
        }
    }

    init(id: Int?) {
        self.id = id
    }
}
