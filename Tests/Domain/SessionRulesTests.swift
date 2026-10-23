import Foundation
import Testing

@testable import Winter

@Suite("Session rules")
struct SessionRulesTests {
    private let start = Date(timeIntervalSince1970: 1_760_000_000)

    @Test("A duration is the number of minutes between start and stop")
    func duration() {
        #expect(SessionRules.duration(start: start, stop: start.addingTimeInterval(138 * 60)) == 138)
    }

    @Test("Seconds are rounded to the nearest minute, so no work is lost")
    func durationRoundsToNearestMinute() {
        #expect(SessionRules.duration(start: start, stop: start.addingTimeInterval(137 * 60 + 45)) == 138)
        #expect(SessionRules.duration(start: start, stop: start.addingTimeInterval(137 * 60 + 10)) == 137)
    }

    @Test("A stop before the start is zero, never negative")
    func durationNeverNegative() {
        #expect(SessionRules.duration(start: start, stop: start.addingTimeInterval(-600)) == 0)
    }

    @Test("A running session has no duration yet")
    func runningSessionHasNoDuration() {
        #expect(SessionRules.duration(of: SessionFacts(start: start)) == nil)
    }

    @Test("Under five minutes is short", arguments: [0, 1, 4])
    func shortSessions(minutes: Minutes) {
        #expect(SessionRules.isShortSession(minutes: minutes))
    }

    @Test("Five minutes is not short any more")
    func fiveMinutesIsNotShort() {
        #expect(!SessionRules.isShortSession(minutes: 5))
    }

    @Test("Over ten hours is long")
    func longSessions() {
        #expect(!SessionRules.isLongSession(minutes: 600))
        #expect(SessionRules.isLongSession(minutes: 601))
    }

    @Test("A running session carries no flags, because its duration is not final")
    func runningSessionHasNoFlags() {
        let facts = SessionFacts(start: start, autoStopped: true, stoppedByOther: true)
        #expect(SessionRules.flags(for: facts).isEmpty)
    }

    @Test("A normal finished session carries no flags")
    func normalSessionHasNoFlags() {
        let facts = SessionFacts(start: start, stop: start.addingTimeInterval(2 * 3600))
        #expect(SessionRules.flags(for: facts).isEmpty)
    }

    @Test("Flags come in a fixed order, so the uploaded description is reproducible")
    func flagOrderIsStable() {
        let facts = SessionFacts(
            start: start,
            stop: start.addingTimeInterval(11 * 3600),
            autoStopped: true,
            stoppedByOther: true
        )
        #expect(SessionRules.flags(for: facts) == [.longSession, .stoppedAutomatically, .stoppedBySomeoneElse])
    }

    @Test("A four-minute session is flagged short")
    func shortSessionIsFlagged() {
        let facts = SessionFacts(start: start, stop: start.addingTimeInterval(4 * 60))
        #expect(SessionRules.flags(for: facts) == [.shortSession])
    }

}
