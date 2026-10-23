import Foundation
import SwiftData
import UIKit

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

    /// A made-up logo — a white glider on blue — so previews and the
    /// `-sampleClub` launch show where a club's logo goes.
    @MainActor
    static var logo: Data? {
        let size = CGSize(width: 256, height: 256)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let symbol = UIImage(
                systemName: "airplane",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 120, weight: .semibold)
            )?.withTintColor(.white, renderingMode: .alwaysOriginal)
            if let symbol {
                symbol.draw(at: CGPoint(x: (size.width - symbol.size.width) / 2, y: (size.height - symbol.size.height) / 2))
            }
        }
        return image.pngData()
    }

    /// Named by registration, as a club does in zweef.app, with the type
    /// alongside. Fictional registrations.
    static let aircraft: [(id: Int, name: String, type: String)] = [
        (101, "OO-ZXA", "Schleicher ASK 21"),
        (102, "OO-ZXB", "Rolladen-Schneider LS4"),
        (103, "OO-ZXC", "Schempp-Hirth Discus b"),
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
            context.insert(Aircraft(zweefId: plane.id, name: plane.name, typeName: plane.type))
        }
        for task in DefaultTasks.seed() {
            context.insert(task)
        }
        let settings = AppSettings(clubName: "Zweefvliegclub Voorbeeld")
        settings.clubLogo = logo
        context.insert(settings)

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

    /// A club with finished sessions from today and an earlier day, one of
    /// them flagged, and one already uploaded.
    ///
    /// This is the state the sync screen is actually interesting in: an empty
    /// database tells you nothing about the layout.
    @MainActor
    static func finishedSessionsContainer(runningSessionCount: Int = 0, now: Date = .now) throws -> ModelContainer {
        let container = try container(runningSessionCount: runningSessionCount, now: now)
        let context = container.mainContext
        let calendar = Calendar.club
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -2, to: today) else {
            return container
        }

        func session(
            memberIndex: Int,
            day: Date,
            fromHour: Int,
            minutes: Int,
            taskKey: String? = "glider",
            autoStopped: Bool = false,
            syncState: SyncState = .local
        ) -> WorkSession {
            let start = calendar.date(byAdding: .hour, value: fromHour, to: day) ?? day
            return WorkSession(
                memberId: members[memberIndex].id,
                start: start,
                stop: start.addingTimeInterval(Double(minutes) * 60),
                status: .completed,
                taskKey: taskKey,
                aircraftId: taskKey == "glider" ? aircraft[0].id : nil,
                autoStopped: autoStopped,
                syncState: syncState
            )
        }

        context.insert(session(memberIndex: 0, day: today, fromHour: 9, minutes: 138))
        context.insert(session(memberIndex: 1, day: today, fromHour: 10, minutes: 45, taskKey: "workshop"))
        context.insert(session(memberIndex: 2, day: today, fromHour: 13, minutes: 3, taskKey: nil))
        context.insert(
            session(
                memberIndex: 3,
                day: yesterday,
                fromHour: 14,
                minutes: 420,
                taskKey: "winch",
                autoStopped: true
            )
        )
        context.insert(
            session(memberIndex: 4, day: yesterday, fromHour: 9, minutes: 90, syncState: .uploaded)
        )

        try context.save()
        return container
    }
}
