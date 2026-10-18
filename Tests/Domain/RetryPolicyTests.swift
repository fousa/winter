import Foundation
import Testing

@testable import Winter

@Suite("Retry policy")
struct RetryPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    @Test("Nothing to wait for before the first attempt")
    func noDelayBeforeTheFirstTry() {
        #expect(RetryPolicy.delay(afterAttempts: 0, jitterFraction: 0) == 0)
    }

    @Test("The wait grows and then settles at a quarter of an hour")
    func backoffGrowsThenFlattens() {
        #expect(RetryPolicy.delay(afterAttempts: 1, jitterFraction: 0) == 30)
        #expect(RetryPolicy.delay(afterAttempts: 2, jitterFraction: 0) == 60)
        #expect(RetryPolicy.delay(afterAttempts: 3, jitterFraction: 0) == 120)
        #expect(RetryPolicy.delay(afterAttempts: 4, jitterFraction: 0) == 300)
        #expect(RetryPolicy.delay(afterAttempts: 5, jitterFraction: 0) == 900)
        // However many times it has failed, it keeps trying every 15 minutes.
        #expect(RetryPolicy.delay(afterAttempts: 40, jitterFraction: 0) == 900)
    }

    @Test("Jitter spreads the wait by up to a fifth, so devices do not retry in step")
    func jitterSpreadsTheWait() {
        #expect(RetryPolicy.delay(afterAttempts: 1, jitterFraction: 1) == 36)
        #expect(RetryPolicy.delay(afterAttempts: 1, jitterFraction: 0.5) == 33)
        // Out-of-range fractions are clamped rather than trusted.
        #expect(RetryPolicy.delay(afterAttempts: 1, jitterFraction: 5) == 36)
        #expect(RetryPolicy.delay(afterAttempts: 1, jitterFraction: -5) == 30)
    }

    @Test("An upload that never failed may be tried immediately")
    func untriedUploadsGoNow() {
        #expect(RetryPolicy.mayRetry(attempts: 0, lastAttempt: nil, now: now, jitterFraction: 0))
        #expect(RetryPolicy.mayRetry(attempts: 0, lastAttempt: now, now: now, jitterFraction: 0))
    }

    @Test("A failed upload waits, then goes")
    func failedUploadsWait() {
        let lastAttempt = now.addingTimeInterval(-20)
        #expect(!RetryPolicy.mayRetry(attempts: 1, lastAttempt: lastAttempt, now: now, jitterFraction: 0))

        let longer = now.addingTimeInterval(-31)
        #expect(RetryPolicy.mayRetry(attempts: 1, lastAttempt: longer, now: now, jitterFraction: 0))
    }

    @Test("Without a recorded attempt there is nothing to wait for")
    func missingLastAttemptIsNotABlocker() {
        #expect(RetryPolicy.mayRetry(attempts: 3, lastAttempt: nil, now: now, jitterFraction: 0))
    }

    @Test("An empty device refreshes whatever the clock says")
    func emptyCacheAlwaysRefreshes() {
        #expect(RetryPolicy.shouldRefresh(lastRefresh: now, now: now, cacheIsEmpty: true))
        #expect(RetryPolicy.shouldRefresh(lastRefresh: nil, now: now, cacheIsEmpty: false))
    }

    @Test("Otherwise the member list is refreshed every six hours")
    func refreshesEverySixHours() {
        let fiveHours = now.addingTimeInterval(-5 * 3600)
        #expect(!RetryPolicy.shouldRefresh(lastRefresh: fiveHours, now: now, cacheIsEmpty: false))

        let sevenHours = now.addingTimeInterval(-7 * 3600)
        #expect(RetryPolicy.shouldRefresh(lastRefresh: sevenHours, now: now, cacheIsEmpty: false))
    }
}
