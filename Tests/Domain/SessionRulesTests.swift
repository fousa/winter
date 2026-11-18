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

    // MARK: - Breaks (ADR 0022)

    /// A break that starts `after` minutes into the session and lasts `minutes`.
    private func pause(after: Int, minutes: Int) -> WorkBreak {
        let from = start.addingTimeInterval(Double(after) * 60)
        return WorkBreak(start: from, end: from.addingTimeInterval(Double(minutes) * 60))
    }

    @Test("A break is not counted: the duration is the time worked")
    func breaksAreTakenOut() {
        let stop = start.addingTimeInterval(413 * 60)
        #expect(SessionRules.duration(start: start, stop: stop, breaks: [pause(after: 198, minutes: 45)]) == 368)
    }

    @Test("Several breaks are all taken out")
    func severalBreaks() {
        let facts = SessionFacts(
            start: start,
            stop: start.addingTimeInterval(8 * 3600),
            breaks: [pause(after: 90, minutes: 15), pause(after: 240, minutes: 30)]
        )
        #expect(SessionRules.duration(of: facts) == 8 * 60 - 45)
        #expect(SessionRules.breakMinutes(of: facts) == 45)
    }

    @Test("A break can never cost more time than the session has")
    func breakIsClippedToTheSession() {
        // A break that runs on past the stop: only the part inside counts.
        let stop = start.addingTimeInterval(120 * 60)
        #expect(SessionRules.duration(start: start, stop: stop, breaks: [pause(after: 100, minutes: 60)]) == 100)
        #expect(SessionRules.duration(start: start, stop: stop, breaks: [pause(after: -30, minutes: 600)]) == 0)
    }

    @Test("A running timer shows the time worked so far, without its breaks")
    func workedMinutesWhileRunning() {
        let facts = SessionFacts(start: start, breaks: [pause(after: 60, minutes: 30)])
        #expect(SessionRules.workedMinutes(of: facts, now: start.addingTimeInterval(200 * 60)) == 170)
    }

    @Test("A paused timer stands still at the moment the break began")
    func workedMinutesWhilePaused() {
        let facts = SessionFacts(start: start, pausedAt: start.addingTimeInterval(198 * 60))
        #expect(SessionRules.workedMinutes(of: facts, now: start.addingTimeInterval(210 * 60)) == 198)
        #expect(SessionRules.workedMinutes(of: facts, now: start.addingTimeInterval(900 * 60)) == 198)
    }

    @Test("A break of an hour is long enough to ask about; 59 minutes is not")
    func longBreak() {
        #expect(!SessionRules.isLongBreak(since: start, now: start.addingTimeInterval(59 * 60)))
        #expect(SessionRules.isLongBreak(since: start, now: start.addingTimeInterval(60 * 60)))
    }

    @Test("Every break length on offer fits inside a break long enough to be asked about")
    func offeredLengthsFitTheThreshold() {
        #expect(SessionRules.breakLengthsOffered.allSatisfy { $0 <= SessionRules.longBreakThreshold })
    }

    @Test("Short and long are judged on the time worked, not on the clock")
    func flagsUseTheTimeWorked() {
        // Eleven hours at the club, two of them on a break: nine worked.
        let facts = SessionFacts(
            start: start,
            stop: start.addingTimeInterval(11 * 3600),
            breaks: [pause(after: 180, minutes: 120)]
        )
        #expect(SessionRules.flags(for: facts).isEmpty)
    }

    @Test("A timer the closing time found paused is flagged as ended on a break, once")
    func endedOnBreakReplacesStoppedAutomatically() {
        let facts = SessionFacts(
            start: start,
            stop: start.addingTimeInterval(198 * 60),
            autoStopped: true,
            endedOnBreak: true
        )
        #expect(SessionRules.flags(for: facts) == [.endedOnBreak])
    }

    @Test("Stopping by hand during a break is no flag: the member chose it")
    func stoppedByHandOnABreakIsNotFlagged() {
        let facts = SessionFacts(start: start, stop: start.addingTimeInterval(198 * 60), endedOnBreak: true)
        #expect(SessionRules.flags(for: facts).isEmpty)
    }

    @Test("The stretches worked are what lies around the breaks")
    func workedStretches() {
        let stop = start.addingTimeInterval(413 * 60)
        let stretches = SessionRules.workedStretches(start: start, stop: stop, breaks: [pause(after: 198, minutes: 45)])
        #expect(stretches == [
            DateInterval(start: start, end: start.addingTimeInterval(198 * 60)),
            DateInterval(start: start.addingTimeInterval(243 * 60), end: stop),
        ])
    }

    @Test("A session that ended on its break has no stretch after it")
    func noStretchAfterTheLastBreak() {
        // Stopped where the second break began; the first one is finished.
        let stop = start.addingTimeInterval(300 * 60)
        let stretches = SessionRules.workedStretches(start: start, stop: stop, breaks: [pause(after: 100, minutes: 20)])
        #expect(stretches.count == 2)
        #expect(stretches.last?.end == stop)
    }

    @Test("A break of under a minute leaves no gap in the times")
    func momentaryBreakIsIgnored() {
        let stop = start.addingTimeInterval(120 * 60)
        let blink = WorkBreak(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(3620))
        #expect(SessionRules.workedStretches(start: start, stop: stop, breaks: [blink]) == [DateInterval(start: start, end: stop)])
    }
}
