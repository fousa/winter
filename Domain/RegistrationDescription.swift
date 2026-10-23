import Foundation

/// Builds the `description` that goes to zweef.app with a registration.
///
/// The times and the member's own comment, nothing else (ADR 0019): the task
/// already travels in `project` and the aircraft in `material_id`, so
/// repeating them here only made the board read everything twice. Assembled in
/// one documented place because the sync engine also compares it, to
/// recognise a registration it may already have uploaded (`docs/sync.md`).
enum RegistrationDescription {
    /// Everything the description is built from.
    struct Input: Equatable, Sendable {
        var start: Date
        var stop: Date
        /// What the member typed when stopping, if anything.
        var comment: String?

        init(start: Date, stop: Date, comment: String? = nil) {
            self.start = start
            self.stop = stop
            self.comment = comment
        }
    }

    /// "09:12–11:30", or "09:12–11:30 · Replaced the canopy seal".
    static func text(for input: Input, timeZone: TimeZone) -> String {
        var parts = [timeRange(from: input.start, to: input.stop, timeZone: timeZone)]
        if let comment = input.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
            parts.append(comment)
        }
        return parts.joined(separator: " · ")
    }

    /// "09:12–11:30", always on a 24-hour clock.
    ///
    /// Fixed rather than locale-dependent on purpose: this is data in somebody
    /// else's database, and devices in different languages should not leave
    /// half the club's history in AM/PM.
    private static func timeRange(from start: Date, to stop: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start))–\(formatter.string(from: stop))"
    }
}
