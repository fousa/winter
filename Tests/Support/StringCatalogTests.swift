import Foundation
import Testing

@testable import Winter

/// Guards the promise that the app ships in three languages.
///
/// The app shipping in English, Dutch and French is a decision
/// ([ADR 0010](../../docs/decisions/0010-three-languages-en-nl-fr.md)), and a
/// decision nobody checks is a wish. A string added in English and forgotten in
/// the other two falls back silently: the app keeps working, a French member
/// just reads English for a release or two and nobody files a bug.
///
/// So the catalog is read from disk and asserted on. This is the only test that
/// looks at a file in the repository rather than at code, which is the point —
/// it fails in the pull request that forgets a translation.
@Suite("String catalog")
struct StringCatalogTests {
    private struct Catalog: Decodable {
        let sourceLanguage: String
        let strings: [String: Entry]

        struct Entry: Decodable {
            let extractionState: String?
            let localizations: [String: Localisation]?
            let comment: String?
        }

        /// Either one value or a set of plural variations.
        struct Localisation: Decodable {
            let stringUnit: Unit?
            let variations: Variations?

            struct Unit: Decodable {
                let state: String
                let value: String
            }

            struct Variations: Decodable {
                let plural: [String: PluralCase]?

                struct PluralCase: Decodable {
                    let stringUnit: Unit?
                }
            }

            /// Whether this language actually has text, in either shape.
            var hasText: Bool {
                if let unit = stringUnit { return !unit.value.isEmpty }
                guard let cases = variations?.plural, !cases.isEmpty else { return false }
                return cases.values.allSatisfy { $0.stringUnit?.value.isEmpty == false }
            }
        }
    }

    private static let required = ["nl", "fr"]

    /// Walks up from this file until it finds the catalog.
    ///
    /// Searching rather than counting directories, so moving this file — or
    /// running the suite from a different layout — does not quietly break it
    /// into a test that passes because it found nothing.
    private func catalogURL() throws -> URL {
        var directory = URL(filePath: #filePath).deletingLastPathComponent()

        for _ in 0..<6 {
            let candidate = directory.appending(path: "Resources/Localizable.xcstrings")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            directory = directory.deletingLastPathComponent()
        }

        throw CatalogNotFound()
    }

    private struct CatalogNotFound: Error, CustomStringConvertible {
        var description: String {
            "Could not find Resources/Localizable.xcstrings above \(#filePath)"
        }
    }

    private func loadCatalog() throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: try catalogURL()))
    }

    @Test("English is the source language")
    func englishIsTheSource() throws {
        #expect(try loadCatalog().sourceLanguage == "en")
    }

    @Test("Every string is translated into Dutch and French")
    func everyStringIsTranslated() throws {
        let catalog = try loadCatalog()

        let untranslated = catalog.strings
            .filter { $0.value.extractionState != "stale" }
            .compactMap { key, entry -> String? in
                let missing = Self.required.filter { entry.localizations?[$0]?.hasText != true }
                return missing.isEmpty ? nil : "\(key) [missing: \(missing.joined(separator: ", "))]"
            }
            .sorted()

        #expect(untranslated.isEmpty, "Untranslated strings:\n\(untranslated.joined(separator: "\n"))")
    }

    @Test("No stale strings: what the code no longer says is not shipped")
    func noStaleStrings() throws {
        let stale = try loadCatalog().strings
            .filter { $0.value.extractionState == "stale" }
            .keys
            .sorted()

        #expect(stale.isEmpty, "Stale strings to remove:\n\(stale.joined(separator: "\n"))")
    }

    @Test("No empty keys, which is what a Picker(\"\") leaves behind")
    func noEmptyKeys() throws {
        #expect(try !loadCatalog().strings.keys.contains(""))
    }

    @Test("A counted string has both plural cases in every language")
    func pluralsAreComplete() throws {
        let catalog = try loadCatalog()

        let incomplete = catalog.strings
            .filter { $0.key.contains("inflect: true") && $0.value.extractionState != "stale" }
            .compactMap { key, entry -> String? in
                let broken = Self.required.filter { language in
                    guard let cases = entry.localizations?[language]?.variations?.plural else { return true }
                    return cases["one"] == nil || cases["other"] == nil
                }
                return broken.isEmpty ? nil : "\(key) [\(broken.joined(separator: ", "))]"
            }
            .sorted()

        #expect(incomplete.isEmpty, """
            Counted strings need explicit one/other variations per language — \
            English inflection does not carry over:
            \(incomplete.joined(separator: "\n"))
            """)
    }

    @Test("French is flagged where it is much longer than English, so layouts get checked")
    func reportsWhereFrenchRunsLong() throws {
        let catalog = try loadCatalog()

        // Not a failure: French runs 20–30% longer by nature, and prose is
        // allowed to wrap. This lists the short labels — the ones that sit in
        // buttons and capsules — where the gap is big enough to be worth
        // looking at on a device.
        let stretched = catalog.strings.compactMap { key, entry -> String? in
            guard key.count < 30,
                  let french = entry.localizations?["fr"]?.stringUnit?.value,
                  french.count > key.count * 2,
                  french.count - key.count > 8
            else { return nil }
            return "\(key) → \(french)"
        }
        .sorted()

        // Reported, never asserted: this test exists to produce a list for the
        // manual pass, not to fail a build over a language's word lengths.
        if !stretched.isEmpty {
            print("Short labels that grow a lot in French, worth checking on a device:")
            for line in stretched { print("  \(line)") }
        }
    }
}
