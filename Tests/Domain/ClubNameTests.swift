import Foundation
import Testing

@testable import Winter

@Suite("Club name")
struct ClubNameTests {
    @Test("With no name at all, the app shows its own")
    func fallsBackToTheAppName() {
        #expect(ClubName.display(stored: nil) == "Winter")
        #expect(ClubName.display(stored: "") == "Winter")
        #expect(ClubName.display(stored: "   ") == "Winter")
    }

    @Test("A stored name is shown as it is, trimmed")
    func showsTheStoredName() {
        #expect(ClubName.display(stored: "Gliding Club Example") == "Gliding Club Example")
        #expect(ClubName.display(stored: "  Gliding Club Example  ") == "Gliding Club Example")
    }

    @Test("A fetched name is adopted when nobody typed one")
    func adoptsAFetchedName() {
        #expect(ClubName.shouldAdopt(fetched: "Gliding Club Example", isManual: false))
    }

    @Test("A typed name survives a later refresh, so nobody's club is renamed")
    func keepsATypedName() {
        #expect(!ClubName.shouldAdopt(fetched: "Gliding Club Example", isManual: true))
    }

    @Test("An empty or blank fetched name is never adopted")
    func ignoresEmptyFetchedNames() {
        #expect(!ClubName.shouldAdopt(fetched: nil, isManual: false))
        #expect(!ClubName.shouldAdopt(fetched: "", isManual: false))
        #expect(!ClubName.shouldAdopt(fetched: "  ", isManual: false))
    }

    @Test("Typing nothing clears the name instead of storing a blank")
    func sanitisesTypedNames() {
        #expect(ClubName.sanitised(typed: "  Gliding Club Example ") == "Gliding Club Example")
        #expect(ClubName.sanitised(typed: "") == nil)
        #expect(ClubName.sanitised(typed: "   ") == nil)
    }
}

@MainActor
@Suite("Club name in settings")
struct AppSettingsClubNameTests {
    @Test("A typed name is remembered as typed")
    func storesATypedName() {
        let settings = AppSettings()
        settings.setClubName(typed: "  Gliding Club Example ")

        #expect(settings.clubName == "Gliding Club Example")
        #expect(settings.clubNameIsManual)
        #expect(settings.displayName == "Gliding Club Example")
    }

    @Test("Clearing the field clears the name and the flag")
    func clearingATypedName() {
        let settings = AppSettings()
        settings.setClubName(typed: "Gliding Club Example")
        settings.setClubName(typed: "")

        #expect(settings.clubName == nil)
        #expect(!settings.clubNameIsManual)
        #expect(settings.displayName == "Winter")
    }

    @Test("A fetched name fills in when nobody typed one")
    func adoptsFetchedName() {
        let settings = AppSettings()
        settings.applyFetchedClubName("Gliding Club Example")

        #expect(settings.clubName == "Gliding Club Example")
        #expect(!settings.clubNameIsManual)
        #expect(settings.clubFetchedAt != nil)
    }

    @Test("zweef.app recovering does not rename a club that typed its name")
    func doesNotOverwriteATypedName() {
        let settings = AppSettings()
        settings.setClubName(typed: "Our Own Name")

        settings.applyFetchedClubName("Something From zweef.app")

        #expect(settings.clubName == "Our Own Name")
        #expect(settings.clubNameIsManual)
        // The attempt is still recorded, so the sync screen can show it.
        #expect(settings.clubFetchedAt != nil)
    }

    @Test("A failed club.json leaves the cached name alone")
    func failedFetchKeepsTheCachedName() {
        let settings = AppSettings()
        settings.applyFetchedClubName("Gliding Club Example")

        // club.json answers 500 for a real club: nothing to adopt.
        settings.applyFetchedClubName(nil)

        #expect(settings.clubName == "Gliding Club Example")
    }
}
