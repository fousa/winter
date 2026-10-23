import Foundation
import Testing

@testable import Winter

@Suite("Member directory")
struct MemberDirectoryTests {
    /// A stand-in for the stored model, so the list rules can be tested without
    /// a database.
    private struct TestMember: MemberListItem {
        var memberId: Int
        var firstName: String
        var lastName: String
        var lastSeenAt: Date?

        init(_ id: Int, _ firstName: String, _ lastName: String, lastSeenAt: Date? = nil) {
            self.memberId = id
            self.firstName = firstName
            self.lastName = lastName
            self.lastSeenAt = lastSeenAt
        }
    }

    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    private var club: [TestMember] {
        [
            TestMember(1, "Jan", "Verhoeven"),
            TestMember(2, "Koen", "Maes"),
            TestMember(3, "Ellen", "Peeters"),
            TestMember(4, "Sofie", "Claes"),
            TestMember(5, "Émile", "Dubois"),
            TestMember(6, "jan", "Peeters"),
        ]
    }

    // MARK: - Working members

    @Test("A working member leaves the list, so their only tile is in Working now")
    func workingMembersAreLeftOut() {
        let idle = MemberDirectory.idle(club, workingIds: [1, 4])
        #expect(idle.map(\.memberId) == [2, 3, 5, 6])
    }

    @Test("Often here fills its places with members who are not working")
    func oftenHereSkipsWorkingMembers() {
        let counts = [1: 5, 2: 4, 3: 3]
        let idle = MemberDirectory.idle(club, workingIds: [1])
        let often = MemberDirectory.oftenHere(from: idle, sessionCounts: counts, limit: 2)
        #expect(often.map(\.memberId) == [2, 3])
    }

    // MARK: - Search

    @Test("An empty query matches everyone, so the list is not empty on open")
    func emptyQueryMatchesAll() {
        #expect(MemberDirectory.search(club, query: "").count == club.count)
        #expect(MemberDirectory.search(club, query: "   ").count == club.count)
    }

    @Test("Search ignores case")
    func searchIgnoresCase() {
        #expect(MemberDirectory.search(club, query: "ELLEN").map(\.memberId) == [3])
    }

    @Test("Search ignores accents, in both directions")
    func searchIgnoresDiacritics() {
        #expect(MemberDirectory.search(club, query: "emile").map(\.memberId) == [5])
        #expect(MemberDirectory.search(club, query: "Émile").map(\.memberId) == [5])
    }

    @Test("Search matches the last name and the full name too")
    func searchMatchesLastAndFullName() {
        #expect(MemberDirectory.search(club, query: "Maes").map(\.memberId) == [2])
        #expect(MemberDirectory.search(club, query: "Jan Verhoeven").map(\.memberId) == [1])
    }

    @Test("Searching a surname shared by two members finds both")
    func searchFindsEveryMatch() {
        #expect(Set(MemberDirectory.search(club, query: "Peeters").map(\.memberId)) == [3, 6])
    }

    @Test("A query nobody matches gives nothing, not everything")
    func searchCanComeUpEmpty() {
        #expect(MemberDirectory.search(club, query: "Zzz").isEmpty)
    }

    // MARK: - Sections

    @Test("Sections are letters of the first name, in alphabetical order")
    func sectionsAreAlphabetical() {
        let sections = MemberDirectory.sections(for: club)
        #expect(sections.map(\.letter) == ["E", "J", "K", "S"])
    }

    @Test("An accented first name sits under its base letter")
    func accentedNamesFoldIntoTheirLetter() {
        let sections = MemberDirectory.sections(for: club)
        let e = sections.first { $0.letter == "E" }
        #expect(e?.members.map(\.memberId) == [3, 5])
    }

    @Test("Members inside a section are sorted by first then last name")
    func membersAreSortedWithinASection() {
        let sections = MemberDirectory.sections(for: club)
        let j = sections.first { $0.letter == "J" }
        // Both are "jan"/"Jan": the last name decides, case-insensitively.
        #expect(j?.members.map(\.memberId) == [6, 1])
    }

    @Test("A name that does not start with a letter lands in # at the end")
    func nonLetterNamesGoLast() {
        let sections = MemberDirectory.sections(for: club + [TestMember(7, "1337", "Hacker")])
        #expect(sections.map(\.letter) == ["E", "J", "K", "S", "#"])
    }

    @Test("No members, no sections")
    func noSectionsWhenEmpty() {
        #expect(MemberDirectory.sections(for: [TestMember]()).isEmpty)
    }

    // MARK: - Often here

    @Test("Nobody is \"often here\" on a fresh install")
    func oftenHereIsEmptyOnAFreshInstall() {
        #expect(MemberDirectory.oftenHere(from: club, sessionCounts: [:]).isEmpty)
    }

    @Test("More sessions in the window means a higher place")
    func oftenHereRanksBySessionCount() {
        let counts = [1: 2, 2: 7, 3: 4]
        let ranked = MemberDirectory.oftenHere(from: club, sessionCounts: counts)
        #expect(ranked.map(\.memberId) == [2, 3, 1])
    }

    @Test("With the same count, whoever was here last comes first")
    func oftenHereFallsBackToLastSeen() {
        let members = [
            TestMember(1, "Jan", "Verhoeven", lastSeenAt: now.addingTimeInterval(-3600)),
            TestMember(2, "Koen", "Maes", lastSeenAt: now),
        ]
        let ranked = MemberDirectory.oftenHere(from: members, sessionCounts: [1: 3, 2: 3])
        #expect(ranked.map(\.memberId) == [2, 1])
    }

    @Test("Someone seen before, with no recent sessions, still counts")
    func oftenHereIncludesSeenMembers() {
        let members = [TestMember(1, "Jan", "Verhoeven", lastSeenAt: now)]
        #expect(MemberDirectory.oftenHere(from: members, sessionCounts: [:]).map(\.memberId) == [1])
    }

    @Test("Only five tiles fit, so only five are returned")
    func oftenHereIsLimited() {
        let counts = Dictionary(uniqueKeysWithValues: club.map { ($0.memberId, 1) })
        #expect(MemberDirectory.oftenHere(from: club, sessionCounts: counts).count == 5)
        #expect(MemberDirectory.oftenHere(from: club, sessionCounts: counts, limit: 2).count == 2)
    }

    // MARK: - Session counts

    @Test("Only sessions inside the window count")
    func sessionCountsRespectTheWindow() {
        let starts: [(memberId: Int, start: Date)] = [
            (1, now.addingTimeInterval(-60 * 60)),
            (1, now.addingTimeInterval(-10 * 24 * 3600)),
            (1, now.addingTimeInterval(-40 * 24 * 3600)),
            (2, now.addingTimeInterval(-29 * 24 * 3600)),
        ]

        let counts = MemberDirectory.sessionCounts(starts: starts, now: now)

        #expect(counts[1] == 2)
        #expect(counts[2] == 1)
        #expect(counts[3] == nil)
    }
}
