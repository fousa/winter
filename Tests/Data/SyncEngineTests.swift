import Foundation
import SwiftData
import Testing

@testable import Winter

@Suite("Sync engine")
struct SyncEngineTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// A clock the test moves by hand. `@unchecked Sendable` behind a lock
    /// because the engine reads it from its own executor.
    private final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Date
        init(_ value: Date) { self.value = value }
        var now: Date {
            get { lock.withLock { value } }
            set { lock.withLock { value = newValue } }
        }
    }

    /// Everything a run needs, with the container held so SwiftData does not
    /// pull it out from under the contexts.
    private struct Fixture {
        let container: ModelContainer
        let api: FakeZweefAPI
        let engine: SyncEngine
        let clock: TestClock

        /// Reads through a fresh context, the way the UI would after a run.
        @MainActor
        func sessions() throws -> [WorkSession] {
            try container.mainContext.fetch(
                FetchDescriptor<WorkSession>(sortBy: [SortDescriptor(\.start)])
            )
        }

        @MainActor
        func settings() throws -> AppSettings {
            try #require(try container.mainContext.fetch(FetchDescriptor<AppSettings>()).first)
        }

        @MainActor
        func logMessages() throws -> [String] {
            try container.mainContext.fetch(FetchDescriptor<SyncLog>()).map(\.message)
        }
    }

    @MainActor
    private func makeFixture(
        now: Date,
        api: FakeZweefAPI = FakeZweefAPI(),
        periodId: Int? = 1,
        members: [(Int, String, String)] = [(101, "Jan", "Verhoeven")],
        material: Bool = true
    ) throws -> Fixture {
        let container = try WinterSchema.inMemoryContainer()
        let context = container.mainContext

        for member in members {
            context.insert(Member(zweefId: member.0, firstName: member.1, lastName: member.2))
        }
        if material {
            context.insert(Material(zweefId: 1, name: "ASK 21", kind: .flying, typeName: "Schleicher ASK 21", isGlider: true))
        }
        let settings = AppSettings(activePeriodId: periodId)
        // Already refreshed, so a test about uploading is not also a test about
        // refreshing.
        settings.lastRefreshAt = now
        context.insert(settings)
        try context.save()

        let clock = TestClock(now)
        let engine = SyncEngine(
            container: container,
            apiProvider: { api },
            calendar: calendar,
            now: { clock.now }
        )
        return Fixture(container: container, api: api, engine: engine, clock: clock)
    }

    @MainActor
    private func addSession(
        to fixture: Fixture,
        memberId: Int = 101,
        start: Date,
        stop: Date?,
        state: SyncState = .ready,
        status: SessionStatus = .completed,
        attempts: Int = 0,
        materialId: Int? = 1
    ) throws -> WorkSession {
        let session = WorkSession(
            memberId: memberId,
            start: start,
            stop: stop,
            status: status,
            materialId: materialId,
            syncState: state,
            attempts: attempts
        )
        fixture.container.mainContext.insert(session)
        try fixture.container.mainContext.save()
        return session
    }

    // MARK: - Uploading

    @Test("Waiting sessions are uploaded and marked")
    @MainActor
    func uploadsReadySessions() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 11, 18))

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.uploaded == 1)
        #expect(outcome.failed == 0)
        let session = try #require(try fixture.sessions().first)
        #expect(session.syncState == .uploaded)
        #expect(session.remoteId == 1)
        #expect(session.uploadedAt == date(15, 18))

        let drafts = await fixture.api.createdDrafts
        #expect(drafts.count == 1)
        #expect(drafts[0].userName == "Jan Verhoeven")
        #expect(drafts[0].hours == 2.3)
        #expect(drafts[0].periodId == 1)
        // What it was on: the material's id, and its name as the project,
        // as zweef.app's own form books it (ADR 0020).
        #expect(drafts[0].materialId == 1)
        #expect(drafts[0].project == "ASK 21")
    }

    @Test("Nothing uploads by itself: only a person tapping Upload sends hours", arguments: [
        SyncEngine.Trigger.appBecameActive, .connectivityReturned, .backgroundRefresh,
    ])
    @MainActor
    func automaticRunsNeverUpload(trigger: SyncEngine.Trigger) async throws {
        let fixture = try makeFixture(now: date(17, 12))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10))
        _ = try addSession(to: fixture, start: date(16, 9), stop: date(16, 10), state: .local)

        let outcome = await fixture.engine.requestSync(trigger)

        #expect(outcome.uploaded == 0)
        #expect(try fixture.sessions().map(\.syncState) == [.ready, .local])
        #expect(await fixture.api.createdDrafts.isEmpty)
    }

    @Test("Upload sends a finished session and leaves a running timer alone")
    @MainActor
    func uploadsUnclosedSessionsAndLeavesRunningOnes() async throws {
        let fixture = try makeFixture(now: date(15, 12))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), state: .local)
        _ = try addSession(to: fixture, start: date(15, 11), stop: nil, state: .local, status: .running)

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.uploaded == 1)
        #expect(try fixture.sessions().map(\.syncState) == [.uploaded, .local])
        #expect(try fixture.sessions()[1].status == .running)
    }

    @Test("A running session is never uploaded")
    @MainActor
    func neverUploadsRunningSessions() async throws {
        let fixture = try makeFixture(now: date(15, 12))
        _ = try addSession(to: fixture, start: date(15, 9), stop: nil, state: .local, status: .running)

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.uploaded == 0)
        #expect(await fixture.api.createdDrafts.isEmpty)
    }

    @Test("Without an active period, sessions stay put rather than being lost")
    @MainActor
    func keepsSessionsWhenThereIsNoPeriod() async throws {
        let fixture = try makeFixture(now: date(15, 18), periodId: nil)
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10))

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.uploaded == 0)
        #expect(try fixture.sessions()[0].syncState == .ready)
        #expect(try fixture.logMessages().contains { $0.contains("No active maintenance period") })
    }

    // MARK: - Failure and retry

    @Test("A dropped connection leaves the session ready to try again")
    @MainActor
    func returnsSessionToReadyOnNetworkFailure() async throws {
        let api = FakeZweefAPI()
        await api.failNextCreates(1)
        let fixture = try makeFixture(now: date(15, 18), api: api)
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10))

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.failed == 1)
        #expect(outcome.error == .unreachable)
        let session = try #require(try fixture.sessions().first)
        #expect(session.syncState == .ready)
        #expect(session.attempts == 1)
    }

    @Test("A 4xx is a rejection with a reason, and is not retried")
    @MainActor
    func marksRejectedWithReason() async throws {
        let api = FakeZweefAPI(create: .failure(.rejected(status: 422, reason: "Member is not active")))
        let fixture = try makeFixture(now: date(15, 18), api: api)
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10))

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.rejected == 1)
        let session = try #require(try fixture.sessions().first)
        #expect(session.syncState == .rejected)
        #expect(session.lastError == "Member is not active")
    }

    @Test("A revoked token stops the run instead of burning through every session")
    @MainActor
    func stopsOnUnauthorised() async throws {
        let api = FakeZweefAPI(create: .failure(.notAuthorised))
        let fixture = try makeFixture(now: date(15, 18), api: api)
        for hour in 9...11 {
            _ = try addSession(
                to: fixture,
                memberId: 101,
                start: date(15, hour),
                stop: date(15, hour).addingTimeInterval(1800)
            )
        }

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.error == .notAuthorised)
        #expect(outcome.failed == 1)
        // Only the first was attempted; the other two were not touched.
        let states = try fixture.sessions().map(\.syncState)
        #expect(states == [.ready, .ready, .ready])
        #expect(try fixture.sessions().map(\.attempts) == [1, 0, 0])
    }

    @Test("A failed upload goes again at the next tap, with no backoff to wait out")
    @MainActor
    func failedUploadGoesAgainAtTheNextTap() async throws {
        let api = FakeZweefAPI()
        await api.failNextCreates(1)
        let fixture = try makeFixture(now: date(15, 18), api: api)
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10))
        await fixture.engine.requestSync(.upload)

        fixture.clock.now = date(15, 18).addingTimeInterval(5)
        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.uploaded == 1)
    }

    @Test("A rejected session is not sent again: zweef.app would say no again")
    @MainActor
    func rejectedSessionsStayOut() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), state: .rejected)

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.uploaded == 0)
        #expect(await fixture.api.createdDrafts.isEmpty)
    }

    // MARK: - Dedup

    @Test("An upload that already arrived is recognised instead of sent twice")
    @MainActor
    func recognisesAnUploadThatAlreadyArrived() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        _ = try addSession(
            to: fixture,
            start: date(15, 9),
            stop: date(15, 10),
            attempts: 1
        )

        // The server has a registration that says exactly what this session
        // would: same member, day, hours and times. The timed-out POST did
        // arrive.
        await fixture.api.setHours(.success([
            ZweefMaintenanceHour(
                id: 99,
                periodId: 1,
                userId: 101,
                date: "2026-10-15",
                hours: 1.0,
                materialId: 1,
                status: "in_aanvraag",
                description: "09:00–10:00"
            )
        ]))

        fixture.clock.now = date(15, 19)
        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.uploaded == 1)
        let stored = try #require(try fixture.sessions().first)
        #expect(stored.syncState == .uploaded)
        #expect(stored.remoteId == 99)
        // Crucially: nothing was posted a second time.
        #expect(await fixture.api.createdDrafts.isEmpty)
    }

    @Test("Someone else's registration at other times is not mistaken for this one")
    @MainActor
    func differentRegistrationIsStillPosted() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), attempts: 1)
        await fixture.api.setHours(.success([
            ZweefMaintenanceHour(
                id: 99, periodId: 1, userId: 101, date: "2026-10-15", hours: 1.0,
                materialId: 1, status: "in_aanvraag", description: "13:00–14:00"
            )
        ]))

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.uploaded == 1)
        #expect(await fixture.api.createdDrafts.count == 1)
    }

    @Test("A session that was never tried is not dedup-checked")
    @MainActor
    func skipsDedupCheckForUntriedSessions() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10))

        await fixture.engine.requestSync(.upload)

        // "hours" is only fetched when something has failed before.
        #expect(await fixture.api.callLog.contains("hours") == false)
    }

    // MARK: - Auto-stop

    @Test("A forgotten timer is stopped at the closing time and uploaded in the same run")
    @MainActor
    func stopsForgottenTimersFirst() async throws {
        let fixture = try makeFixture(now: date(16, 9))
        _ = try addSession(to: fixture, start: date(15, 14), stop: nil, state: .local, status: .running)

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(outcome.autoStopped == 1)
        let session = try #require(try fixture.sessions().first)
        #expect(session.stop == date(15, 21))
        #expect(session.autoStopped)
        #expect(session.syncState == .uploaded)
        let drafts = await fixture.api.createdDrafts
        // The times as stopped by the closing time; the flag itself stays on
        // the device (ADR 0019).
        #expect(drafts[0].description == "14:00–21:00")
    }

    @Test("The member's comment travels to zweef.app after the times")
    @MainActor
    func commentIsUploaded() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        let session = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10))
        session.comment = "Canopy seal replaced"
        try fixture.container.mainContext.save()

        _ = await fixture.engine.requestSync(.upload)

        let drafts = await fixture.api.createdDrafts
        #expect(drafts.first?.description == "09:00–10:00 · Canopy seal replaced")
    }

    // MARK: - Refresh

    @Test("An empty device fetches members and material before anything else")
    @MainActor
    func refreshesAnEmptyDevice() async throws {
        let fixture = try makeFixture(now: date(15, 12), members: [], material: false)
        try fixture.settings().lastRefreshAt = nil
        try fixture.container.mainContext.save()

        let outcome = await fixture.engine.requestSync(.appBecameActive)

        #expect(outcome.refreshed)
        let members = try fixture.container.mainContext.fetch(FetchDescriptor<Member>())
        #expect(members.count == 4)
        let material = try fixture.container.mainContext.fetch(FetchDescriptor<Material>())
        func item(_ id: Int) -> Material? { material.first { $0.zweefId == id } }
        // All of zweef.app's list, in its three tabs: three aircraft, the
        // winch, and the club itself.
        #expect(material.count == 5)
        #expect(item(1)?.kind == .flying)
        #expect(item(4)?.kind == .rolling)
        #expect(item(5)?.kind == .other)
        #expect(item(1)?.typeName == "Schleicher ASK 21")
        // A member's own glider is stored but not offered.
        #expect(item(1)?.isOffered == true)
        #expect(item(3)?.isOffered == false)
        #expect(item(4)?.isOffered == true)
    }

    @Test("A device without material refreshes at once, not after six hours")
    @MainActor
    func refreshesWhenMaterialIsMissing() async throws {
        // Members are there and the last refresh was just now — as on a device
        // updated from the build that kept only aircraft.
        let fixture = try makeFixture(now: date(15, 12), material: false)

        let outcome = await fixture.engine.requestSync(.appBecameActive)

        #expect(outcome.refreshed)
        #expect(try fixture.container.mainContext.fetchCount(FetchDescriptor<Material>()) == 5)
    }

    @Test("Material zweef.app no longer lists is removed from the device")
    @MainActor
    func removesMaterialThatIsGone() async throws {
        let fixture = try makeFixture(now: date(15, 12))
        fixture.container.mainContext.insert(Material(zweefId: 99, name: "Sold glider", kind: .flying))
        try fixture.settings().lastRefreshAt = nil
        try fixture.container.mainContext.save()

        await fixture.engine.requestSync(.appBecameActive)

        let ids = try fixture.container.mainContext.fetch(FetchDescriptor<Material>()).map(\.zweefId)
        #expect(!ids.contains(99))
    }

    @Test("A refresh within six hours is skipped")
    @MainActor
    func skipsRefreshWhenRecent() async throws {
        let fixture = try makeFixture(now: date(15, 12))

        let outcome = await fixture.engine.requestSync(.appBecameActive)

        #expect(!outcome.refreshed)
        #expect(await fixture.api.callLog.contains("accounts") == false)
    }

    @Test("Refreshing twice does not duplicate a member")
    @MainActor
    func refreshIsAnUpsert() async throws {
        let fixture = try makeFixture(now: date(15, 12), members: [(101, "Old", "Name")])
        try fixture.settings().lastRefreshAt = nil
        try fixture.container.mainContext.save()

        await fixture.engine.requestSync(.appBecameActive)
        try fixture.settings().lastRefreshAt = nil
        try fixture.container.mainContext.save()
        await fixture.engine.requestSync(.appBecameActive)

        let members = try fixture.container.mainContext.fetch(FetchDescriptor<Member>())
        #expect(members.count == 4)
        let updated = try #require(members.first { $0.zweefId == 101 })
        #expect(updated.firstName == "Jan")
    }

    @Test("A club.json that answers 500 does not stop the refresh")
    @MainActor
    func survivesABrokenClubEndpoint() async throws {
        let api = FakeZweefAPI(club: .failure(.server(status: 500)))
        let fixture = try makeFixture(now: date(15, 12), api: api, members: [])
        try fixture.settings().lastRefreshAt = nil
        try fixture.container.mainContext.save()

        let outcome = await fixture.engine.requestSync(.appBecameActive)

        #expect(outcome.refreshed)
        #expect(try fixture.settings().clubName == nil)
        #expect(try fixture.container.mainContext.fetch(FetchDescriptor<Member>()).count == 4)
    }

    @Test("A typed club name survives a refresh that brings a different one")
    @MainActor
    func keepsATypedClubName() async throws {
        let fixture = try makeFixture(now: date(15, 12), members: [])
        let settings = try fixture.settings()
        settings.setClubName(typed: "Our Own Name")
        settings.lastRefreshAt = nil
        try fixture.container.mainContext.save()

        await fixture.engine.requestSync(.appBecameActive)

        #expect(try fixture.settings().clubName == "Our Own Name")
    }

    @Test("A refresh that fails still lets the hours go up")
    @MainActor
    func uploadsEvenWhenRefreshFails() async throws {
        let api = FakeZweefAPI(accounts: .failure(.unreachable))
        let fixture = try makeFixture(now: date(15, 18), api: api)
        try fixture.settings().lastRefreshAt = nil
        try fixture.container.mainContext.save()
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10))

        let outcome = await fixture.engine.requestSync(.upload)

        #expect(!outcome.refreshed)
        #expect(outcome.uploaded == 1)
    }

    // MARK: - One run at a time

    @Test("Triggers that arrive during a run are merged into one follow-up")
    @MainActor
    func mergesConcurrentTriggers() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        for hour in 9...12 {
            _ = try addSession(
                to: fixture,
                start: date(15, hour),
                stop: date(15, hour).addingTimeInterval(1800)
            )
        }

        // Five triggers at once: one run does the work, and no session is
        // uploaded twice.
        async let first = fixture.engine.requestSync(.upload)
        async let second = fixture.engine.requestSync(.connectivityReturned)
        async let third = fixture.engine.requestSync(.appBecameActive)
        async let fourth = fixture.engine.requestSync(.upload)
        async let fifth = fixture.engine.requestSync(.backgroundRefresh)
        let outcomes = await [first, second, third, fourth, fifth]

        #expect(outcomes.map(\.uploaded).reduce(0, +) == 4)
        #expect(await fixture.api.createdDrafts.count == 4)
        #expect(try fixture.sessions().allSatisfy { $0.syncState == .uploaded })
    }

    @Test("The sync log records what happened, and no member's name")
    @MainActor
    func logsWithoutPersonalData() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10))

        await fixture.engine.requestSync(.upload)

        let messages = try fixture.logMessages()
        #expect(messages.contains { $0.contains("Uploaded 1 session") })
        #expect(!messages.contains { $0.contains("Jan") || $0.contains("Verhoeven") })
    }
}
