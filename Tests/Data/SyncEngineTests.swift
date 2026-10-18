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
        tasks: Bool = true
    ) throws -> Fixture {
        let container = try WinterSchema.inMemoryContainer()
        let context = container.mainContext

        for member in members {
            context.insert(Member(zweefId: member.0, firstName: member.1, lastName: member.2))
        }
        if tasks {
            for task in DefaultTasks.seed(locale: Locale(identifier: "en")) { context.insert(task) }
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
            api: api,
            flagLabel: { flag in flag.rawValue },
            calendar: calendar,
            now: { clock.now },
            // No jitter, so backoff windows are exact in tests.
            jitter: { 0 }
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
        taskKey: String? = "glider",
        closedAt: Date? = nil
    ) throws -> WorkSession {
        let session = WorkSession(
            memberId: memberId,
            start: start,
            stop: stop,
            status: status,
            taskKey: taskKey,
            syncState: state,
            attempts: attempts,
            dayClosedAt: closedAt
        )
        fixture.container.mainContext.insert(session)
        try fixture.container.mainContext.save()
        return session
    }

    // MARK: - Uploading

    @Test("A closed day's sessions are uploaded and marked")
    @MainActor
    func uploadsReadySessions() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 11, 18), closedAt: date(15, 18))

        let outcome = await fixture.engine.requestSync(.dayClosed)

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
        // The label as the club stores it, whatever language it was seeded in.
        let gliderLabel = try #require(
            try fixture.container.mainContext
                .fetch(FetchDescriptor<TaskDefinition>())
                .first { $0.key == "glider" }?.label
        )
        #expect(drafts[0].project == gliderLabel)
    }

    @Test("A session whose day is not closed is left alone for a day")
    @MainActor
    func leavesUnclosedSessionsAlone() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), state: .local)

        let outcome = await fixture.engine.requestSync(.appBecameActive)

        #expect(outcome.uploaded == 0)
        #expect(try fixture.sessions()[0].syncState == .local)
        #expect(await fixture.api.createdDrafts.isEmpty)
    }

    @Test("After a day, an unclosed session is uploaded anyway, so hours never get stuck")
    @MainActor
    func uploadsOldUnclosedSessions() async throws {
        let fixture = try makeFixture(now: date(17, 12))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), state: .local)

        let outcome = await fixture.engine.requestSync(.appBecameActive)

        #expect(outcome.uploaded == 1)
        #expect(try fixture.sessions()[0].syncState == .uploaded)
    }

    @Test("A running session is never uploaded")
    @MainActor
    func neverUploadsRunningSessions() async throws {
        let fixture = try makeFixture(now: date(15, 12))
        _ = try addSession(to: fixture, start: date(15, 9), stop: nil, state: .local, status: .running)

        let outcome = await fixture.engine.requestSync(.manual)

        #expect(outcome.uploaded == 0)
        #expect(await fixture.api.createdDrafts.isEmpty)
    }

    @Test("Without an active period, sessions stay put rather than being lost")
    @MainActor
    func keepsSessionsWhenThereIsNoPeriod() async throws {
        let fixture = try makeFixture(now: date(15, 18), periodId: nil)
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), closedAt: date(15, 18))

        let outcome = await fixture.engine.requestSync(.dayClosed)

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
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), closedAt: date(15, 18))

        let outcome = await fixture.engine.requestSync(.dayClosed)

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
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), closedAt: date(15, 18))

        let outcome = await fixture.engine.requestSync(.dayClosed)

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
                stop: date(15, hour).addingTimeInterval(1800),
                closedAt: date(15, 18)
            )
        }

        let outcome = await fixture.engine.requestSync(.dayClosed)

        #expect(outcome.error == .notAuthorised)
        #expect(outcome.failed == 1)
        // Only the first was attempted; the other two were not touched.
        let states = try fixture.sessions().map(\.syncState)
        #expect(states == [.ready, .ready, .ready])
        #expect(try fixture.sessions().map(\.attempts) == [1, 0, 0])
    }

    @Test("A failed upload waits for its backoff before being tried again")
    @MainActor
    func respectsBackoff() async throws {
        let api = FakeZweefAPI()
        await api.failNextCreates(1)
        let fixture = try makeFixture(now: date(15, 18), api: api)
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), closedAt: date(15, 18))

        await fixture.engine.requestSync(.dayClosed)

        // 20 seconds later: inside the 30 second window, so nothing is sent.
        fixture.clock.now = date(15, 18).addingTimeInterval(20)
        let tooSoon = await fixture.engine.requestSync(.connectivityReturned)
        #expect(tooSoon.uploaded == 0)
        #expect(await fixture.api.createdDrafts.isEmpty)

        // 31 seconds later: the window has passed.
        fixture.clock.now = date(15, 18).addingTimeInterval(31)
        let later = await fixture.engine.requestSync(.connectivityReturned)
        #expect(later.uploaded == 1)
    }

    @Test("\"Try again now\" ignores the backoff, because someone is watching")
    @MainActor
    func manualRetryIgnoresBackoff() async throws {
        let api = FakeZweefAPI()
        await api.failNextCreates(1)
        let fixture = try makeFixture(now: date(15, 18), api: api)
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), closedAt: date(15, 18))
        await fixture.engine.requestSync(.dayClosed)

        fixture.clock.now = date(15, 18).addingTimeInterval(5)
        let outcome = await fixture.engine.requestSync(.manual)

        #expect(outcome.uploaded == 1)
    }

    // MARK: - Dedup

    @Test("An upload that already arrived is recognised instead of sent twice")
    @MainActor
    func recognisesAnUploadThatAlreadyArrived() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        let session = try addSession(
            to: fixture,
            start: date(15, 9),
            stop: date(15, 10),
            attempts: 1,
            closedAt: date(15, 18)
        )

        // The server has the registration, carrying the tag this session put
        // in its description — the timed-out POST did arrive.
        await fixture.api.setHours(.success([
            ZweefMaintenanceHour(
                id: 99,
                periodId: 1,
                userId: 101,
                date: "2026-10-15",
                hours: 1.0,
                materialId: nil,
                status: "in_aanvraag",
                description: "Glider · 09:00–10:00 \(RegistrationDescription.dedupTag(for: session.id))"
            )
        ]))

        fixture.clock.now = date(15, 19)
        let outcome = await fixture.engine.requestSync(.manual)

        #expect(outcome.uploaded == 1)
        let stored = try #require(try fixture.sessions().first)
        #expect(stored.syncState == .uploaded)
        #expect(stored.remoteId == 99)
        // Crucially: nothing was posted a second time.
        #expect(await fixture.api.createdDrafts.isEmpty)
    }

    @Test("A session that was never tried is not dedup-checked")
    @MainActor
    func skipsDedupCheckForUntriedSessions() async throws {
        let fixture = try makeFixture(now: date(15, 18))
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), closedAt: date(15, 18))

        await fixture.engine.requestSync(.dayClosed)

        // "hours" is only fetched when something has failed before.
        #expect(await fixture.api.callLog.contains("hours") == false)
    }

    // MARK: - Auto-stop

    @Test("A forgotten timer is stopped at the closing time and uploaded in the same run")
    @MainActor
    func stopsForgottenTimersFirst() async throws {
        let fixture = try makeFixture(now: date(16, 9))
        _ = try addSession(to: fixture, start: date(15, 14), stop: nil, state: .local, status: .running)

        // Two days on, so the 24 hour safety net also applies.
        fixture.clock.now = date(17, 9)
        let outcome = await fixture.engine.requestSync(.appBecameActive)

        #expect(outcome.autoStopped == 1)
        let session = try #require(try fixture.sessions().first)
        #expect(session.stop == date(15, 21))
        #expect(session.autoStopped)
        #expect(session.syncState == .uploaded)
        let drafts = await fixture.api.createdDrafts
        #expect(drafts[0].description.contains("stoppedAutomatically"))
    }

    // MARK: - Refresh

    @Test("An empty device fetches members and aircraft before anything else")
    @MainActor
    func refreshesAnEmptyDevice() async throws {
        let fixture = try makeFixture(now: date(15, 12), members: [], tasks: false)
        try fixture.settings().lastRefreshAt = nil
        try fixture.container.mainContext.save()

        let outcome = await fixture.engine.requestSync(.appBecameActive)

        #expect(outcome.refreshed)
        let members = try fixture.container.mainContext.fetch(FetchDescriptor<Member>())
        #expect(members.count == 4)
        let aircraft = try fixture.container.mainContext.fetch(FetchDescriptor<Aircraft>())
        // Three items of material, but the winch is not an aircraft.
        #expect(aircraft.count == 2)
        #expect(aircraft.allSatisfy { $0.isGlider })
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
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), closedAt: date(15, 18))

        let outcome = await fixture.engine.requestSync(.dayClosed)

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
                stop: date(15, hour).addingTimeInterval(1800),
                closedAt: date(15, 18)
            )
        }

        // Five triggers at once: one run does the work, and no session is
        // uploaded twice.
        async let first = fixture.engine.requestSync(.dayClosed)
        async let second = fixture.engine.requestSync(.connectivityReturned)
        async let third = fixture.engine.requestSync(.appBecameActive)
        async let fourth = fixture.engine.requestSync(.manual)
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
        _ = try addSession(to: fixture, start: date(15, 9), stop: date(15, 10), closedAt: date(15, 18))

        await fixture.engine.requestSync(.dayClosed)

        let messages = try fixture.logMessages()
        #expect(messages.contains { $0.contains("Uploaded 1 session") })
        #expect(!messages.contains { $0.contains("Jan") || $0.contains("Verhoeven") })
    }
}
