import Foundation

/// How long to wait before trying an upload again.
///
/// The club's connection comes and goes, so retrying is the normal case rather
/// than the exception. Backing off matters for the opposite reason to most
/// apps: not to spare the server, but to spare the battery of a device that
/// sits on a wall all day with no signal.
enum RetryPolicy {
    /// 30 s, 1 m, 2 m, 5 m, then every 15 m (`docs/sync.md`).
    ///
    /// Fast at first, because the most common failure is a connection that
    /// drops for a moment; then slow, because the second most common one is a
    /// hangar with no coverage at all.
    static let delays: [TimeInterval] = [30, 60, 120, 300, 900]

    /// The wait after `attempts` failures.
    ///
    /// - Parameters:
    ///   - attempts: How many times this upload has already failed. 0 means it
    ///     has not been tried, so there is nothing to wait for.
    ///   - jitterFraction: 0…1, spreading the wait by up to 20%. Injected so
    ///     tests are deterministic — and it exists at all so that a club with
    ///     several devices does not have them all retry on the same second.
    static func delay(afterAttempts attempts: Int, jitterFraction: Double = .random(in: 0...1)) -> TimeInterval {
        guard attempts > 0 else { return 0 }

        let base = delays[min(attempts - 1, delays.count - 1)]
        let jitter = base * 0.2 * min(max(jitterFraction, 0), 1)
        return base + jitter
    }

    /// Whether an upload that failed `attempts` times at `lastAttempt` may be
    /// tried again now.
    static func mayRetry(
        attempts: Int,
        lastAttempt: Date?,
        now: Date,
        jitterFraction: Double = .random(in: 0...1)
    ) -> Bool {
        guard attempts > 0, let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= delay(afterAttempts: attempts, jitterFraction: jitterFraction)
    }

    /// How often the member list, aircraft and club name are refreshed.
    ///
    /// Six hours: a club gains a member every few weeks, and a device in a
    /// hangar should not spend its battery asking.
    static let refreshInterval: TimeInterval = 6 * 60 * 60

    /// Whether a refresh is due.
    ///
    /// An empty cache is always due, whatever the clock says: a device that has
    /// never synced has no member list to show.
    static func shouldRefresh(lastRefresh: Date?, now: Date, cacheIsEmpty: Bool) -> Bool {
        if cacheIsEmpty { return true }
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= refreshInterval
    }

    /// A finished session that nobody closed is uploaded anyway after a day.
    ///
    /// The safety net from `docs/spec.md`: hours must not sit on a device
    /// forever because the last person out forgot the button.
    static let unclosedSessionGrace: TimeInterval = 24 * 60 * 60
}
