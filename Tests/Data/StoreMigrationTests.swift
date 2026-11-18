import Foundation
import SwiftData
import Testing

@testable import Winter

/// Guards the hours that are already on a device when the app is updated.
///
/// The app opens its database with no migration plan: SwiftData migrates by
/// itself, which only works while every change to a model is one it can make
/// on its own — a new optional field, or one with a default. If that ever
/// fails the app cannot open its store at all (`AppEnvironment.live` stops
/// there on purpose), with members' hours inside it. So the store is written
/// here by the models as they were, and opened by the models as they are.
@MainActor
@Suite("Store migration")
struct StoreMigrationTests {
    /// The session model as it shipped before a timer could be paused
    /// (ADR 0022): no `pausedAt`, no breaks, no `endedOnBreak`.
    ///
    /// Nested so it can carry the same name as the real model, which is what
    /// SwiftData matches on.
    enum BeforePause {
        @Model
        final class WorkSession {
            #Unique<WorkSession>([\.id])

            var id: UUID
            var memberId: Int
            var start: Date
            var stop: Date?
            var status: SessionStatus
            @Attribute(originalName: "aircraftId") var materialId: Int?
            var autoStopped: Bool
            var stoppedByOther: Bool
            var comment: String?
            var syncState: SyncState
            var remoteId: Int?
            var lastError: String?
            var attempts: Int
            var lastAttemptAt: Date?
            var uploadedAt: Date?

            init(memberId: Int, start: Date, stop: Date?, status: SessionStatus, comment: String? = nil) {
                self.id = UUID()
                self.memberId = memberId
                self.start = start
                self.stop = stop
                self.status = status
                self.materialId = 101
                self.autoStopped = false
                self.stoppedByOther = false
                self.comment = comment
                self.syncState = .local
                self.attempts = 0
            }
        }

        static let models: [any PersistentModel.Type] = [
            Member.self,
            Material.self,
            WorkSession.self,
            AppSettings.self,
            SyncLog.self,
        ]
    }

    @Test("A database from before pausing opens, with every session as it was")
    func opensAStoreFromBeforePause() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "winter-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Winter.store")

        let start = Date(timeIntervalSince1970: 1_760_000_000)

        // Written by the old models, then closed.
        do {
            let old = try ModelContainer(
                for: Schema(BeforePause.models),
                configurations: ModelConfiguration(url: url)
            )
            old.mainContext.insert(Member(zweefId: 1, firstName: "Jan", lastName: "Verhoeven"))
            old.mainContext.insert(
                BeforePause.WorkSession(
                    memberId: 1,
                    start: start,
                    stop: start.addingTimeInterval(138 * 60),
                    status: .completed,
                    comment: "Replaced the canopy seal"
                )
            )
            old.mainContext.insert(
                BeforePause.WorkSession(memberId: 2, start: start.addingTimeInterval(3600), stop: nil, status: .running)
            )
            try old.mainContext.save()
        }

        // Opened by the app as it is now.
        let container = try ModelContainer(
            for: Schema(WinterSchema.models),
            configurations: ModelConfiguration(url: url)
        )
        let sessions = try container.mainContext.fetch(
            FetchDescriptor<WorkSession>(sortBy: [SortDescriptor(\.start)])
        )

        #expect(sessions.count == 2)
        let finished = try #require(sessions.first)
        #expect(finished.status == .completed)
        #expect(finished.minutes == 138)
        #expect(finished.comment == "Replaced the canopy seal")
        #expect(finished.materialId == 101)
        #expect(finished.breaks.isEmpty)
        #expect(finished.pausedAt == nil)
        #expect(!finished.endedOnBreak)

        // And the timer that was running through the update can be paused.
        let running = try #require(sessions.last)
        #expect(running.status == .running)
        #expect(!running.isPaused)
        let store = SessionStore(context: container.mainContext, now: { start.addingTimeInterval(2 * 3600) })
        try store.pause(running)
        #expect(running.isPaused)
    }
}
