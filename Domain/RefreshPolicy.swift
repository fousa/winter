import Foundation

/// When the member list, aircraft and club name are fetched again.
///
/// The one thing the app still does with the network by itself: uploading
/// waits for a person (ADR 0015), but a new member should not have to wait
/// for anyone before they can find their name.
enum RefreshPolicy {
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
}
