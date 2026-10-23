import Foundation
import Testing

@testable import Winter

@Suite("Registration description")
struct RegistrationDescriptionTests {
    private let timeZone = TimeZone(identifier: "Europe/Brussels")!

    private var start: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 9, minute: 12))!
    }

    @Test("Without a comment, the description is the times alone")
    func timesOnly() {
        let input = RegistrationDescription.Input(start: start, stop: start.addingTimeInterval(138 * 60))
        #expect(RegistrationDescription.text(for: input, timeZone: timeZone) == "09:12–11:30")
    }

    @Test("A comment follows the times, trimmed")
    func withComment() {
        let input = RegistrationDescription.Input(
            start: start,
            stop: start.addingTimeInterval(3600),
            comment: "  Replaced the canopy seal \n"
        )
        #expect(RegistrationDescription.text(for: input, timeZone: timeZone) == "09:12–10:12 · Replaced the canopy seal")
    }

    @Test("A comment of only spaces leaves no stray separator")
    func blankCommentIsSkipped() {
        let input = RegistrationDescription.Input(start: start, stop: start.addingTimeInterval(3600), comment: "   ")
        #expect(RegistrationDescription.text(for: input, timeZone: timeZone) == "09:12–10:12")
    }

    @Test("Times are on a 24-hour clock, whatever the device's language")
    func timesAreAlwaysTwentyFourHour() {
        let input = RegistrationDescription.Input(
            start: start.addingTimeInterval(8 * 3600),
            stop: start.addingTimeInterval(10 * 3600)
        )

        let text = RegistrationDescription.text(for: input, timeZone: timeZone)

        #expect(text == "17:12–19:12")
        #expect(!text.lowercased().contains("pm"))
    }
}
