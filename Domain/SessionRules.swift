import Foundation

/// The rules that decide what a session means, as pure functions.
///
/// Everything here is deliberately free of storage, UI and clocks: the view
/// layer asks these questions ("may the day be closed?") instead of answering
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

    /// The duration of a session in whole minutes, rounded to the nearest minute.
    ///
    /// Rounded rather than truncated so that 2 h 17 m 45 s is reported as 2 h 18 m
    /// instead of silently losing most of a minute. A stop before the start
    /// cannot happen through the UI; if it somehow does, the duration is zero
    /// rather than negative, because a negative number of hours would be
    /// rejected by zweef.app and lose the session.
    static func duration(start: Date, stop: Date) -> Minutes {
        let seconds = stop.timeIntervalSince(start)
        guard seconds > 0 else { return 0 }
        return Int((seconds / 60).rounded())
    }

    /// The duration of a session, or `nil` while it is still running.
    static func duration(of facts: SessionFacts) -> Minutes? {
        guard let stop = facts.stop else { return nil }
        return duration(start: facts.start, stop: stop)
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
        if facts.autoStopped { flags.append(.stoppedAutomatically) }
        if facts.stoppedByOther { flags.append(.stoppedBySomeoneElse) }
        return flags
    }

    /// Whether the day may be closed.
    ///
    /// Anyone may close the day, but only once nothing is running (ADR 0005):
    /// closing with a timer still going would upload an unfinished session or
    /// leave it stranded.
    static func canCloseDay(runningCount: Int) -> Bool {
        runningCount == 0
    }
}
