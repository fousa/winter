import Foundation
import Testing

@testable import Winter

@Suite("Refresh policy")
struct RefreshPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    @Test("An empty device refreshes whatever the clock says")
    func emptyCacheAlwaysRefreshes() {
        #expect(RefreshPolicy.shouldRefresh(lastRefresh: now, now: now, cacheIsEmpty: true))
        #expect(RefreshPolicy.shouldRefresh(lastRefresh: nil, now: now, cacheIsEmpty: false))
    }

    @Test("Otherwise the member list is refreshed every six hours")
    func refreshesEverySixHours() {
        let fiveHours = now.addingTimeInterval(-5 * 3600)
        #expect(!RefreshPolicy.shouldRefresh(lastRefresh: fiveHours, now: now, cacheIsEmpty: false))

        let sevenHours = now.addingTimeInterval(-7 * 3600)
        #expect(RefreshPolicy.shouldRefresh(lastRefresh: sevenHours, now: now, cacheIsEmpty: false))
    }
}
