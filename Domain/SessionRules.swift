import Foundation

/// The rules that decide what a session means, as pure functions.
///
/// Everything here is deliberately free of storage, UI and clocks: the view
/// layer asks these questions ("is this session short?") instead of answering
/// them itself, so the answers can be tested at the edges where they matter —
/// midnight, the closing time, daylight saving.
enum SessionRules {
    /// Under five minutes we ask "is that right?" before saving.
    ///
    /// The threshold exists because the most common mistake on a shared device
    /// is tapping the wrong name and stopping again straight away.
    static let shortSessionThreshold: Minutes = 5

    /// Over ten hours is almost certainly a timer someone forgot.
    static let longSessionThreshold: Minutes = 10 * 60

    /// A break this long is probably a member who forgot to resume, so the
    /// app starts asking (ADR 0022).
    ///
    /// An hour, because a lunch at a club rarely runs longer, and because it
    /// is the longest of ``breakLengthsOffered``: every length on offer then
    /// fits inside the break it is offered for.
    static let longBreakThreshold: Minutes = 60

    /// What "how long was your break really?" offers, in minutes.
    static let breakLengthsOffered: [Minutes] = [30, 45, 60]

    /// The time worked between `start` and `stop` in whole minutes, rounded
    /// to the nearest minute, with the breaks taken out.
    ///
    /// Rounded rather than truncated so that 2 h 17 m 45 s is reported as 2 h 18 m
    /// instead of silently losing most of a minute. A stop before the start
    /// cannot happen through the UI; if it somehow does, the duration is zero
    /// rather than negative, because a negative number of hours would be
    /// rejected by zweef.app and lose the session.
    ///
    /// Only the part of a break that lies between `start` and `stop` is taken
    /// out, so a break can never cost more time than the session has.
    static func duration(start: Date, stop: Date, breaks: [WorkBreak] = []) -> Minutes {
        let paused = breaks.reduce(0.0) { total, pause in
            let from = max(pause.start, start)
            let to = min(pause.end, stop)
            return total + max(0, to.timeIntervalSince(from))
        }
        let seconds = stop.timeIntervalSince(start) - paused
        guard seconds > 0 else { return 0 }
        return Int((seconds / 60).rounded())
    }

    /// The time worked in a finished session, or `nil` while it is still
    /// running.
    static func duration(of facts: SessionFacts) -> Minutes? {
        guard let stop = facts.stop else { return nil }
        return duration(start: facts.start, stop: stop, breaks: facts.breaks)
    }

    /// The time worked so far, for a timer on screen.
    ///
    /// While the member is on a break it stands still at the moment the break
    /// began: that is what "paused" has to look like on a tile.
    static func workedMinutes(of facts: SessionFacts, now: Date) -> Minutes {
        duration(start: facts.start, stop: facts.stop ?? facts.pausedAt ?? now, breaks: facts.breaks)
    }

    /// How long the finished breaks of a session took together.
    static func breakMinutes(of facts: SessionFacts) -> Minutes {
        let end = facts.stop ?? .distantFuture
        let seconds = facts.breaks.reduce(0.0) { total, pause in
            total + max(0, min(pause.end, end).timeIntervalSince(max(pause.start, facts.start)))
        }
        return Int((seconds / 60).rounded())
    }

    /// Whether a break that began at `pausedAt` has gone on long enough to
    /// ask if someone forgot to resume.
    static func isLongBreak(since pausedAt: Date, now: Date) -> Bool {
        duration(start: pausedAt, stop: now) >= longBreakThreshold
    }

    /// The stretches of a session that were actually worked: everything
    /// between `start` and `stop` that is not a break.
    ///
    /// This is what the registration's description lists (ADR 0022). A break
    /// of under a minute is ignored: written to the minute it would read as
    /// "10:30–10:30", a gap nobody took.
    static func workedStretches(start: Date, stop: Date, breaks: [WorkBreak]) -> [DateInterval] {
        var stretches: [DateInterval] = []
        var cursor = start

        for pause in breaks.sorted(by: { $0.start < $1.start }) {
            let from = max(pause.start, cursor)
            let to = min(pause.end, stop)
            guard to.timeIntervalSince(from) >= 60 else { continue }
            if from > cursor { stretches.append(DateInterval(start: cursor, end: from)) }
            cursor = to
        }

        if stop > cursor || stretches.isEmpty {
            stretches.append(DateInterval(start: cursor, end: max(cursor, stop)))
        }
        return stretches
    }

    static func isShortSession(minutes: Minutes) -> Bool {
        minutes < shortSessionThreshold
    }

    static func isLongSession(minutes: Minutes) -> Bool {
        minutes > longSessionThreshold
    }

    /// Every flag that applies to a session, in a stable order.
    ///
    /// The order is fixed so that the description uploaded to zweef.app is
    /// reproducible: the sync engine compares descriptions to spot a
    /// registration it may have uploaded twice.
    ///
    /// A running session has no flags yet — not even "short" — because its
    /// duration is not final.
    static func flags(for facts: SessionFacts) -> [SessionFlag] {
        guard let minutes = duration(of: facts) else { return [] }

        var flags: [SessionFlag] = []
        if isShortSession(minutes: minutes) { flags.append(.shortSession) }
        if isLongSession(minutes: minutes) { flags.append(.longSession) }
        if facts.autoStopped {
            // One or the other: both would say the same thing twice.
            flags.append(facts.endedOnBreak ? .endedOnBreak : .stoppedAutomatically)
        }
        if facts.stoppedByOther { flags.append(.stoppedBySomeoneElse) }
        return flags
    }

}
