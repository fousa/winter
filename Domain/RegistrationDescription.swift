import Foundation

/// Builds the `description` that goes to zweef.app with a registration.
///
/// This string does double duty: it is what the board reads in zweef.app, and
/// it carries the dedup tag the sync engine uses to recognise a registration it
/// may already have uploaded (`docs/zweef-api.md`). That is why it is assembled
/// in one documented place instead of in the sync engine.
enum RegistrationDescription {
    /// Everything the description is built from.
    struct Input: Equatable, Sendable {
        /// The session's local id; its prefix becomes the dedup tag.
        var sessionId: UUID
        var start: Date
        var stop: Date
        /// The club's own task label, shown as the club typed it (ADR 0010).
        var taskLabel: String?
        var aircraftName: String?
        var flags: [SessionFlag]

        init(
            sessionId: UUID,
            start: Date,
            stop: Date,
            taskLabel: String? = nil,
            aircraftName: String? = nil,
            flags: [SessionFlag] = []
        ) {
            self.sessionId = sessionId
            self.start = start
            self.stop = stop
            self.taskLabel = taskLabel
            self.aircraftName = aircraftName
            self.flags = flags
        }
    }

    /// The description for one registration.
    ///
    /// `flagLabel` is injected rather than looked up here so that `Domain` stays
    /// free of bundles and string catalogs. The caller resolves the labels in
    /// the club's *reporting* language, not the language of whoever tapped Stop,
    /// so the board reads one consistent list (ADR 0010).
    static func text(
        for input: Input,
        flagLabel: (SessionFlag) -> String,
        timeZone: TimeZone
    ) -> String {
        var parts: [String] = []
        if let taskLabel = input.taskLabel, !taskLabel.isEmpty { parts.append(taskLabel) }
        if let aircraftName = input.aircraftName, !aircraftName.isEmpty { parts.append(aircraftName) }
        parts.append(timeRange(from: input.start, to: input.stop, timeZone: timeZone))
        parts.append(contentsOf: input.flags.map(flagLabel))

        return parts.joined(separator: " · ") + " " + dedupTag(for: input.sessionId)
    }

    /// The machine key that makes an upload recognisable after an unclear
    /// response. Never translated and never reformatted.
    static func dedupTag(for sessionId: UUID) -> String {
        "[ou:\(shortId(for: sessionId))]"
    }

    /// Whether a description from zweef.app belongs to this session.
    ///
    /// Used after a timeout, when the app cannot tell whether its POST arrived:
    /// finding the tag means the registration is already there and must not be
    /// uploaded twice.
    static func describes(sessionId: UUID, description: String) -> Bool {
        description.contains(dedupTag(for: sessionId))
    }

    private static func shortId(for sessionId: UUID) -> String {
        String(sessionId.uuidString.lowercased().replacing("-", with: "").prefix(8))
    }

    /// "09:12–11:30", always on a 24-hour clock.
    ///
    /// Fixed rather than locale-dependent on purpose: this is data in somebody
    /// else's database, and a club that switches its reporting language should
    /// not end up with half its history in AM/PM.
    private static func timeRange(from start: Date, to stop: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start))–\(formatter.string(from: stop))"
    }
}
