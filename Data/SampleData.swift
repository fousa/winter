import Foundation
import SwiftData

/// The fictional club used by previews and tests.
///
/// The same members and aircraft as the mockups, so a preview looks like the
/// design. Fictional on purpose: no real member data belongs in the repository
/// (SECURITY.md), not even in previews.
enum SampleData {
    static let members: [(id: Int, first: String, last: String)] = [
        (1, "Jan", "Verhoeven"),
        (2, "Koen", "Maes"),
        (3, "Ellen", "Peeters"),
        (4, "Sofie", "Claes"),
        (5, "Bart", "Wouters"),
        (6, "Lotte", "Janssens"),
        (7, "Pieter", "De Smet"),
    ]

    static let aircraft: [(id: Int, name: String)] = [
        (101, "ASK 21"),
        (102, "LS4"),
        (103, "Discus"),
    ]

    /// An in-memory container with the sample club in it.
    ///
    /// - Parameter runningSessionCount: How many members are working, so a
    ///   preview can show the "Working now" bar empty, with a few cards, or
    ///   busy.
    @MainActor
    static func container(runningSessionCount: Int = 0, now: Date = .now) throws -> ModelContainer {
        let container = try WinterSchema.inMemoryContainer()
        let context = container.mainContext

        for member in members {
            context.insert(Member(zweefId: member.id, firstName: member.first, lastName: member.last))
        }
        for plane in aircraft {
            context.insert(Aircraft(zweefId: plane.id, name: plane.name))
        }
        for task in DefaultTasks.seed() {
            context.insert(task)
        }
        context.insert(AppSettings(clubName: "Zweefvliegclub Voorbeeld"))

        for index in 0..<min(runningSessionCount, members.count) {
            context.insert(
                WorkSession(
                    memberId: members[index].id,
                    // Staggered starts, so the running timers in a preview do
                    // not all show the same number.
                    start: now.addingTimeInterval(Double(-(index + 1) * 23 * 60))
                )
            )
        }

        try context.save()
        return container
    }
}
