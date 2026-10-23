import Foundation

/// The language the generated words in a registration are written in when
/// they go to zweef.app — the flags, such as "short session".
///
/// The language this device runs the app in (ADR 0017). There is no club
/// setting any more: one fewer question during setup, and a club whose
/// devices share a language sees one language in zweef.app anyway.
struct ReportingLanguage: Hashable, Sendable {
    /// One of the three languages the app ships in.
    let code: String

    static let english = ReportingLanguage(code: "en")
    static let dutch = ReportingLanguage(code: "nl")
    static let french = ReportingLanguage(code: "fr")

    /// Falls back to English for anything we do not ship, which is the same
    /// fallback the UI has.
    init(code: String) {
        let normalised = String(code.prefix(2)).lowercased()
        self.code = ["en", "nl", "fr"].contains(normalised) ? normalised : "en"
    }

    /// The language the app runs in on this device.
    ///
    /// Read from the bundle's resolved localisation rather than the device
    /// locale, so it is always one of the three the app ships in and follows
    /// a per-app language set in the iOS Settings app.
    static var device: ReportingLanguage {
        ReportingLanguage(code: Bundle.main.preferredLocalizations.first ?? "en")
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
