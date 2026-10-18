import Foundation
import Testing

@testable import Winter

@Suite("Closing time")
struct ClosingTimeTests {
    /// A fixed calendar, so these tests say the same thing on a machine in any
    /// time zone.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        calendar.locale = Locale(identifier: "en_BE")
        return calendar
    }()

    private let closing = DateComponents(hour: 21, minute: 0)

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func parts(_ date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    @Test("An afternoon session stops at the closing time that same evening")
    func stopsSameDay() {
        let stop = ClosingTime.autoStopDate(for: date(2026, 10, 15, 14, 5), closing: closing, calendar: calendar)
        #expect(parts(stop) == DateComponents(year: 2026, month: 10, day: 15, hour: 21, minute: 0))
    }

    @Test("A session that starts after the closing time waits for the next day")
    func startedAfterClosingWaitsForTomorrow() {
        let stop = ClosingTime.autoStopDate(for: date(2026, 10, 15, 21, 30), closing: closing, calendar: calendar)
        #expect(parts(stop) == DateComponents(year: 2026, month: 10, day: 16, hour: 21, minute: 0))
    }

    @Test("A session that starts exactly at the closing time is not stopped instantly")
    func startedAtClosingIsNotStoppedInstantly() {
        let start = date(2026, 10, 15, 21, 0)
        let stop = ClosingTime.autoStopDate(for: start, closing: closing, calendar: calendar)
        #expect(stop > start)
        #expect(parts(stop) == DateComponents(year: 2026, month: 10, day: 16, hour: 21, minute: 0))
    }

    @Test("A session started just after midnight stops the same evening")
    func startedJustAfterMidnight() {
        let stop = ClosingTime.autoStopDate(for: date(2026, 10, 15, 0, 10), closing: closing, calendar: calendar)
        #expect(parts(stop) == DateComponents(year: 2026, month: 10, day: 15, hour: 21, minute: 0))
    }

    @Test("Spring forward: the next day's closing time is still 21:00 on the clock")
    func survivesSpringForward() {
        // The night of 28 to 29 March 2026 loses an hour in Brussels.
        let stop = ClosingTime.autoStopDate(for: date(2026, 3, 28, 22, 0), closing: closing, calendar: calendar)
        #expect(parts(stop) == DateComponents(year: 2026, month: 3, day: 29, hour: 21, minute: 0))
    }

    @Test("Autumn: the next day's closing time is still 21:00 on the clock")
    func survivesFallBack() {
        // The night of 24 to 25 October 2026 gains an hour in Brussels.
        let stop = ClosingTime.autoStopDate(for: date(2026, 10, 24, 22, 0), closing: closing, calendar: calendar)
        #expect(parts(stop) == DateComponents(year: 2026, month: 10, day: 25, hour: 21, minute: 0))
    }

    @Test("A different closing time is honoured")
    func honoursOtherClosingTimes() {
        let stop = ClosingTime.autoStopDate(
            for: date(2026, 10, 15, 14, 0),
            closing: DateComponents(hour: 18, minute: 30),
            calendar: calendar
        )
        #expect(parts(stop) == DateComponents(year: 2026, month: 10, day: 15, hour: 18, minute: 30))
    }

    @Test("Nothing is stopped before the closing time has passed")
    func shouldAutoStopOnlyAfterClosing() {
        let start = date(2026, 10, 15, 14, 0)
        #expect(!ClosingTime.shouldAutoStop(start: start, now: date(2026, 10, 15, 20, 59), closing: closing, calendar: calendar))
        #expect(ClosingTime.shouldAutoStop(start: start, now: date(2026, 10, 15, 21, 0), closing: closing, calendar: calendar))
    }

    @Test("A timer forgotten overnight is still stopped the next morning")
    func stopsForgottenTimerFromYesterday() {
        let start = date(2026, 10, 15, 14, 0)
        #expect(ClosingTime.shouldAutoStop(start: start, now: date(2026, 10, 16, 9, 0), closing: closing, calendar: calendar))
    }
}
