import Foundation
import Testing

@testable import Winter

@Suite("Registration description")
struct RegistrationDescriptionTests {
    private let timeZone = TimeZone(identifier: "Europe/Brussels")!
    private let sessionId = UUID(uuidString: "A1B2C3D4-0000-0000-0000-000000000000")!

    private var start: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 9, minute: 12))!
    }

    /// Stands in for the string catalog, so the domain layer can be tested
    /// without a bundle.
    private func label(_ flag: SessionFlag) -> String {
        switch flag {
        case .shortSession: "short session"
        case .longSession: "long session"
        case .stoppedAutomatically: "stopped automatically"
        case .stoppedBySomeoneElse: "stopped by someone else"
        }
    }

    @Test("Task, aircraft and time range, with the dedup tag at the end")
    func fullDescription() {
        let input = RegistrationDescription.Input(
            sessionId: sessionId,
            start: start,
            stop: start.addingTimeInterval(138 * 60),
            taskLabel: "Glider",
            aircraftName: "ASK 21"
        )

        let text = RegistrationDescription.text(for: input, flagLabel: label, timeZone: timeZone)

        #expect(text == "Glider · ASK 21 · 09:12–11:30 [ou:a1b2c3d4]")
    }

    @Test("Without a task or aircraft, the time range still carries the session")
    func minimalDescription() {
        let input = RegistrationDescription.Input(
            sessionId: sessionId,
            start: start,
            stop: start.addingTimeInterval(3600)
        )

        let text = RegistrationDescription.text(for: input, flagLabel: label, timeZone: timeZone)

        #expect(text == "09:12–10:12 [ou:a1b2c3d4]")
    }

    @Test("Flags go after the times, before the tag")
    func flagsComeLast() {
        let input = RegistrationDescription.Input(
            sessionId: sessionId,
            start: start,
            stop: start.addingTimeInterval(3600),
            taskLabel: "Glider",
            flags: [.stoppedAutomatically, .stoppedBySomeoneElse]
        )

        let text = RegistrationDescription.text(for: input, flagLabel: label, timeZone: timeZone)

        #expect(text == "Glider · 09:12–10:12 · stopped automatically · stopped by someone else [ou:a1b2c3d4]")
    }

    @Test("An empty task label is left out instead of leaving a stray separator")
    func emptyLabelsAreSkipped() {
        let input = RegistrationDescription.Input(
            sessionId: sessionId,
            start: start,
            stop: start.addingTimeInterval(3600),
            taskLabel: "",
            aircraftName: ""
        )

        let text = RegistrationDescription.text(for: input, flagLabel: label, timeZone: timeZone)

        #expect(text == "09:12–10:12 [ou:a1b2c3d4]")
    }

    @Test("Times are on a 24-hour clock, whatever the club's language")
    func timesAreAlwaysTwentyFourHour() {
        let input = RegistrationDescription.Input(
            sessionId: sessionId,
            start: start.addingTimeInterval(8 * 3600),
            stop: start.addingTimeInterval(10 * 3600)
        )

        let text = RegistrationDescription.text(for: input, flagLabel: label, timeZone: timeZone)

        #expect(text.contains("17:12–19:12"))
        #expect(!text.lowercased().contains("pm"))
    }

    @Test("The dedup tag is the first eight characters of the session id")
    func dedupTag() {
        #expect(RegistrationDescription.dedupTag(for: sessionId) == "[ou:a1b2c3d4]")
    }

    @Test("A description from zweef.app is recognised as this session's")
    func recognisesItsOwnDescription() {
        let other = UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000000")!
        let description = "Glider · 09:12–10:12 [ou:a1b2c3d4]"

        #expect(RegistrationDescription.describes(sessionId: sessionId, description: description))
        #expect(!RegistrationDescription.describes(sessionId: other, description: description))
    }
}
