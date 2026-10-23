import Foundation

/// What the member list needs to know about a member.
///
/// A protocol rather than a struct so the rules below can work on the stored
/// `Member` without `Domain` importing SwiftData, and on a stub in the tests.
protocol MemberListItem {
    var memberId: Int { get }
    var firstName: String { get }
    var lastName: String { get }
    var lastSeenAt: Date? { get }
}

/// Turns a flat list of members into what the home screen shows: a search
/// result, letter sections, and the handful of people who are here most.
///
/// Pure functions, so the ranking that decides who gets the big tiles can be
/// tested instead of being eyeballed in a simulator.
enum MemberDirectory {
    /// How far back "Recents" looks.
    static let recencyWindow: TimeInterval = 30 * 24 * 60 * 60

    /// How many members get a tile in "Recents".
    static let oftenHereLimit = 5

    /// Whether a member matches what someone typed.
    ///
    /// Diacritics- and case-insensitive, because a member looking for *Sofie*
    /// should not have to find the accents on *Sofié*, and the shared device's
    /// keyboard language is whatever the last person left it on.
    static func matches(_ item: some MemberListItem, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        return [item.firstName, item.lastName, "\(item.firstName) \(item.lastName)"]
            .contains { $0.folded.contains(query.folded) }
    }

    /// The members without a running timer.
    ///
    /// A working member's tile moves to "Working now" rather than appearing
    /// twice, so the alphabetical list and "Recents" are built from the
    /// rest — and "Recents" fills its five places with people who can
    /// actually start.
    static func idle<Item: MemberListItem>(_ items: [Item], workingIds: Set<Int>) -> [Item] {
        items.filter { !workingIds.contains($0.memberId) }
    }

    static func search<Item: MemberListItem>(_ items: [Item], query: String) -> [Item] {
        items.filter { matches($0, query: query) }
    }

    /// Members grouped under a letter, in reading order.
    ///
    /// Grouped and sorted by *first* name: a club calls each other by first
    /// name, and that is the name the tile shows large. Accents fold into their
    /// base letter so Émile sits under E, and anything that is not a letter
    /// lands in "#" instead of creating a section of its own.
    static func sections<Item: MemberListItem>(for items: [Item]) -> [MemberSection<Item>] {
        let sorted = items.sorted {
            ($0.firstName.folded, $0.lastName.folded) < ($1.firstName.folded, $1.lastName.folded)
        }

        return Dictionary(grouping: sorted, by: { letter(for: $0) })
            .map { MemberSection(letter: $0.key, members: $0.value) }
            .sorted { lhs, rhs in
                // "#" last, letters alphabetically.
                if lhs.letter == "#" { return false }
                if rhs.letter == "#" { return true }
                return lhs.letter < rhs.letter
            }
    }

    /// The members who are here most often, for the tiles at the top.
    ///
    /// Ranked by how many sessions they logged in the last 30 days, then by who
    /// was here most recently. Members who have never been seen are left out:
    /// on a fresh install "Recents" should be empty rather than show five
    /// arbitrary names.
    static func oftenHere<Item: MemberListItem>(
        from items: [Item],
        sessionCounts: [Int: Int],
        limit: Int = oftenHereLimit
    ) -> [Item] {
        items
            .filter { (sessionCounts[$0.memberId] ?? 0) > 0 || $0.lastSeenAt != nil }
            .sorted { lhs, rhs in
                let lhsCount = sessionCounts[lhs.memberId] ?? 0
                let rhsCount = sessionCounts[rhs.memberId] ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }

                switch (lhs.lastSeenAt, rhs.lastSeenAt) {
                case let (left?, right?) where left != right: return left > right
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs.firstName.folded < rhs.firstName.folded
                }
            }
            .prefix(limit)
            .map { $0 }
    }

    /// How many sessions each member logged inside the recency window.
    static func sessionCounts(
        starts: [(memberId: Int, start: Date)],
        now: Date,
        window: TimeInterval = recencyWindow
    ) -> [Int: Int] {
        let cutoff = now.addingTimeInterval(-window)
        return starts.reduce(into: [:]) { counts, session in
            guard session.start >= cutoff else { return }
            counts[session.memberId, default: 0] += 1
        }
    }

    private static func letter(for item: some MemberListItem) -> String {
        guard let first = item.firstName.folded.uppercased().first, first.isLetter else { return "#" }
        return String(first)
    }
}

/// One letter's worth of members.
struct MemberSection<Item: MemberListItem>: Identifiable {
    var letter: String
    var members: [Item]

    var id: String { letter }
}

extension String {
    /// Case- and diacritics-folded, for comparing names typed by a human.
    var folded: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
