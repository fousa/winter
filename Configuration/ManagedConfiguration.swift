import Foundation

/// Configuration handed down by the club's MDM, which wins over anything typed
/// on the device.
///
/// A club with Apple Business Manager can push the schema and the closing time,
/// so there is less to type on a device mounted on a wall. The API key is
/// deliberately *not* among them: an MDM payload is readable on the device, and
/// a key that opens the club's whole API does not belong in one
/// ([ADR 0013](0013-no-proxy.md)).
///
/// Managed values are read-only in the settings screen: letting someone edit a
/// value the MDM will overwrite tonight is worse than not offering it.
///
/// Parsed once into typed values rather than kept as the raw dictionary, so it
/// is a plain `Sendable` value and the parsing rules live in one place.
struct ManagedConfiguration: Sendable {
    /// The keys a club can set. Documented in `docs/configuration.md`, so
    /// renaming one here is a breaking change for every club using MDM.
    enum Field: String, CaseIterable, Sendable {
        case clubSchema
        case closingTime
    }

    let clubSchema: String?
    /// `HH:mm` from the MDM, parsed into the components the closing time needs.
    let closingTime: DateComponents?

    /// Apple's own key for Managed App Configuration.
    init(defaults: UserDefaults = .standard) {
        self.init(values: defaults.dictionary(forKey: "com.apple.configuration.managed") ?? [:])
    }

    /// For tests, and for previews of the "managed by your organisation" rows.
    init(values: [String: Any]) {
        func string(_ field: Field) -> String? {
            guard let value = values[field.rawValue] as? String else { return nil }
            let trimmed = value.trimmed
            return trimmed.isEmpty ? nil : trimmed
        }

        clubSchema = string(.clubSchema)

        // A malformed time is ignored rather than guessed at: a club that
        // pushes "nine o'clock" should keep the app's default, not have its
        // timers stopped at an hour nobody chose.
        if let raw = string(.closingTime) {
            let parts = raw.split(separator: ":")
            if parts.count == 2,
               let hour = Int(parts[0]), let minute = Int(parts[1]),
               (0..<24).contains(hour), (0..<60).contains(minute) {
                closingTime = DateComponents(hour: hour, minute: minute)
            } else {
                closingTime = nil
            }
        } else {
            closingTime = nil
        }
    }

    /// Which fields the MDM actually set.
    var presentFields: Set<Field> {
        var fields: Set<Field> = []
        if clubSchema != nil { fields.insert(.clubSchema) }
        if closingTime != nil { fields.insert(.closingTime) }
        return fields
    }

    var isEmpty: Bool { presentFields.isEmpty }
}
