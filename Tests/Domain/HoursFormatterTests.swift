import Foundation
import Testing

@testable import Winter

@Suite("Hours formatter")
struct HoursFormatterTests {
    @Test("Minutes become decimal hours with two decimals")
    func decimalHours() {
        #expect(HoursFormatter.decimalHours(minutes: 135) == 2.25)
        #expect(HoursFormatter.decimalHours(minutes: 138) == 2.3)
        #expect(HoursFormatter.decimalHours(minutes: 60) == 1.0)
        #expect(HoursFormatter.decimalHours(minutes: 0) == 0.0)
    }

    @Test("A third of an hour rounds to two decimals rather than repeating")
    func decimalHoursRounds() {
        #expect(HoursFormatter.decimalHours(minutes: 20) == 0.33)
        #expect(HoursFormatter.decimalHours(minutes: 50) == 0.83)
    }

    @Test("Durations read naturally in each of the three languages")
    func durationTextPerLanguage() {
        let english = HoursFormatter.durationText(minutes: 138, locale: Locale(identifier: "en"))
        let dutch = HoursFormatter.durationText(minutes: 138, locale: Locale(identifier: "nl"))
        let french = HoursFormatter.durationText(minutes: 138, locale: Locale(identifier: "fr"))

        #expect(english.contains("2"))
        #expect(english.contains("18"))
        #expect(dutch.contains("2"))
        #expect(dutch.contains("18"))
        #expect(french.contains("2"))
        #expect(french.contains("18"))
    }

    @Test("Under an hour, the zero hours are left out")
    func durationTextHidesZeroHours() {
        let text = HoursFormatter.durationText(minutes: 18, locale: Locale(identifier: "en"))
        #expect(text.contains("18"))
        #expect(!text.contains("0"))
    }

    @Test("A running time has no leading zeros, and no hours under one")
    func compactDuration() {
        #expect(HoursFormatter.compactDuration(minutes: 0) == "0m")
        #expect(HoursFormatter.compactDuration(minutes: 46) == "46m")
        #expect(HoursFormatter.compactDuration(minutes: 65) == "1h05m")
        #expect(HoursFormatter.compactDuration(minutes: 120) == "2h00m")
        #expect(HoursFormatter.compactDuration(minutes: 750) == "12h30m")
    }
}
