import Foundation

/// The language the club's hours are written in when they go to zweef.app.
///
/// Separate from the UI language on purpose: the app follows the device, but a
/// club's maintenance-hours list should not end up with Dutch flags on one row
/// and French on the next depending on whose phone stopped the timer
/// (ADR 0010).
struct ReportingLanguage: Equatable, Sendable {
    /// One of the three languages the app ships in.
    let code: String

    static let english = ReportingLanguage(code: "en")
    static let dutch = ReportingLanguage(code: "nl")
    static let french = ReportingLanguage(code: "fr")

    /// Every language a club can pick, in no particular order of preference.
    static let supported = [english, dutch, french]

    /// Falls back to English for anything we do not ship, which is the same
    /// fallback the UI has.
    init(code: String) {
        let normalised = String(code.prefix(2)).lowercased()
        self.code = ["en", "nl", "fr"].contains(normalised) ? normalised : "en"
    }

    /// The language suggested during setup: whatever the device is in.
    static var deviceDefault: ReportingLanguage {
        ReportingLanguage(code: Locale.current.language.languageCode?.identifier ?? "en")
    }

    var locale: Locale {
        Locale(identifier: code)
    }

    /// The label for a flag, resolved in this language rather than the device's.
    ///
    /// This is the function handed to ``RegistrationDescription`` so that the
    /// domain layer never has to know about bundles.
    func label(for flag: SessionFlag) -> String {
        switch flag {
        case .shortSession: localized("flag.shortSession")
        case .longSession: localized("flag.longSession")
        case .stoppedAutomatically: localized("flag.stoppedAutomatically")
        case .stoppedBySomeoneElse: localized("flag.stoppedBySomeoneElse")
        }
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(key, locale: locale))
    }
}
