import Foundation
import SwiftData
import Testing

@testable import Winter

@MainActor
@Suite("Session store")
struct SessionStoreTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return calendar
    }()

    private let closing = DateComponents(hour: 21, minute: 0)

    /// A clock the test moves by hand, so nothing depends on how long a test
    /// takes to run.
    private final class TestClock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// Everything a test needs, including the container.
    ///
    /// The container is held on to deliberately: a `ModelContext` does not keep
    /// its container alive, and SwiftData traps if the container is released
    /// while the context is still in use.
    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let store: SessionStore
        let clock: TestClock
    }

    private func makeFixture(now: Date) throws -> Fixture {
        let container = try WinterSchema.inMemoryContainer()
        let context = container.mainContext
        let clock = TestClock(now)
        return Fixture(
            container: container,
            context: context,
            store: SessionStore(context: context, calendar: calendar, now: { clock.now }),
            clock: clock
        )
    }

    private func makeMember(_ context: ModelContext, id: Int = 1) throws -> Member {
        let member = Member(zweefId: id, firstName: "Jan", lastName: "Verhoeven")
        context.insert(member)
        try context.save()
        return member
    }

    // MARK: - Starting

    @Test("Starting saves a running session immediately")
    func startSavesRunningSession() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)

        let session = try fixture.store.start(member: member)

        #expect(session.status == .running)
        #expect(session.stop == nil)
        #expect(session.start == date(15, 9, 12))
        #expect(session.memberId == member.zweefId)
        #expect(try fixture.store.runningSessions().count == 1)
        #expect(!fixture.context.hasChanges)
    }

    @Test("Starting records when the member was last seen, for \"often here\"")
    func startUpdatesLastSeen() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)

        try fixture.store.start(member: member)

        #expect(member.lastSeenAt == date(15, 9, 12))
    }

    @Test("A member cannot have two running sessions, and is pointed at the first")
    func startTwiceIsRefused() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let first = try fixture.store.start(member: member)

        #expect(throws: SessionStore.StoreError.memberAlreadyWorking(sessionId: first.id)) {
            try fixture.store.start(member: member)
        }
        #expect(try fixture.store.runningSessions().count == 1)
    }

    @Test("Two different members can work at the same time")
    func twoMembersCanWork() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let jan = try makeMember(fixture.context, id: 1)
        let koen = try makeMember(fixture.context, id: 2)

        try fixture.store.start(member: jan)
        try fixture.store.start(member: koen)

        #expect(try fixture.store.runningSessions().count == 2)
    }

    // MARK: - Stopping

    @Test("Stopping completes the session and leaves it waiting for the day to close")
    func stopCompletesSession() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)

        fixture.clock.now = date(15, 11, 30)
        try fixture.store.stop(session)

        #expect(session.status == .completed)
        #expect(session.stop == date(15, 11, 30))
        #expect(session.syncState == .local)
        #expect(session.minutes == 138)
        #expect(session.stoppedByOther == false)
        #expect(try fixture.store.runningSessions().isEmpty)
    }

    @Test("What the work was on is optional, and stored when picked")
    func stopStoresTheMaterial() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let lier = Material(zweefId: 4, name: "Lier", kind: .rolling)
        fixture.context.insert(lier)
        let session = try fixture.store.start(member: member)

        fixture.clock.now = date(15, 11, 30)
        try fixture.store.stop(session, material: lier)

        #expect(session.materialId == 4)
    }

    @Test("Stopping someone else's timer is allowed, and flagged")
    func stopByOtherIsFlagged() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)

        fixture.clock.now = date(15, 11, 30)
        try fixture.store.stop(session, by: .someoneElse)

        #expect(session.stoppedByOther)
        #expect(session.flags == [.stoppedBySomeoneElse])
    }

    @Test("A session that is not running cannot be stopped twice")
    func stopTwiceIsRefused() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)
        fixture.clock.now = date(15, 11, 30)
        try fixture.store.stop(session)

        #expect(throws: SessionStore.StoreError.sessionNotRunning) {
            try fixture.store.stop(session)
        }
    }

    @Test("A short session is flagged, not refused")
    func shortSessionIsFlaggedNotRefused() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)

        fixture.clock.now = date(15, 9, 16)
        try fixture.store.stop(session)

        #expect(session.flags == [.shortSession])
        #expect(session.status == .completed)
    }

    // MARK: - Undo

    @Test("Undoing a start removes the session, because it never happened")
    func undoStartDeletesSession() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)

        try fixture.store.undoStart(session)

        #expect(try fixture.store.runningSessions().isEmpty)
        #expect(try fixture.store.sessions(onDayOf: date(15, 12)).isEmpty)
    }

    @Test("Undoing a stop puts the timer back, as if Stop had not been tapped")
    func undoStopResumesSession() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let lier = Material(zweefId: 4, name: "Lier", kind: .rolling)
        fixture.context.insert(lier)
        let session = try fixture.store.start(member: member)
        fixture.clock.now = date(15, 11, 30)
        try fixture.store.stop(session, material: lier, comment: "Wings waxed", by: .someoneElse)

        try fixture.store.undoStop(session)

        #expect(session.status == .running)
        #expect(session.stop == nil)
        #expect(session.materialId == nil)
        #expect(session.comment == nil)
        #expect(session.stoppedByOther == false)
        #expect(session.start == date(15, 9, 12))
        #expect(try fixture.store.runningSessions().count == 1)
    }

    @Test("The comment is stored trimmed, and an empty one as nothing")
    func storesTheComment() throws {
        let fixture = try makeFixture(now: date(15, 9))
        let jan = try makeMember(fixture.context, id: 1)
        let koen = try makeMember(fixture.context, id: 2)
        let first = try fixture.store.start(member: jan)
        let second = try fixture.store.start(member: koen)
        fixture.clock.now = date(15, 10)

        try fixture.store.stop(first, comment: "  Wings waxed \n")
        try fixture.store.stop(second, comment: "   ")

        #expect(first.comment == "Wings waxed")
        #expect(second.comment == nil)
    }

    @Test("A running session cannot have its stop undone")
    func undoStopNeedsACompletedSession() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)

        #expect(throws: SessionStore.StoreError.sessionNotCompleted) {
            try fixture.store.undoStop(session)
        }
    }

    // MARK: - Discarding

    @Test("Discarding a running timer removes it, so nothing reaches zweef.app")
    func discardRemovesRunningSession() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)
        fixture.clock.now = date(15, 11, 30)

        try fixture.store.discard(session)

        #expect(try fixture.store.runningSessions().isEmpty)
        #expect(try fixture.store.sessions(onDayOf: date(15, 12)).isEmpty)
        #expect(!fixture.context.hasChanges)
    }

    @Test("After discarding, the member can start again")
    func discardFreesTheMember() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let first = try fixture.store.start(member: member)
        try fixture.store.discard(first)
        fixture.clock.now = date(15, 9, 20)

        let second = try fixture.store.start(member: member)

        #expect(second.start == date(15, 9, 20))
        #expect(try fixture.store.runningSessions().count == 1)
    }

    @Test("A finished session cannot be discarded; corrections happen in zweef.app")
    func discardNeedsARunningSession() throws {
        let fixture = try makeFixture(now: date(15, 9, 12))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)
        fixture.clock.now = date(15, 11, 30)
        try fixture.store.stop(session)

        #expect(throws: SessionStore.StoreError.sessionNotRunning) {
            try fixture.store.discard(session)
        }
        #expect(try fixture.store.sessions(onDayOf: date(15, 12)).count == 1)
    }

    // MARK: - Automatic stop

    @Test("A forgotten timer is stopped at the closing time, not when it is noticed")
    func autoStopUsesClosingTime() throws {
        let fixture = try makeFixture(now: date(15, 14))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)

        // Noticed the next morning.
        fixture.clock.now = date(16, 9)
        let stopped = try fixture.store.applyAutoStop(closing: closing)

        #expect(stopped == 1)
        #expect(session.status == .completed)
        #expect(session.stop == date(15, 21))
        #expect(session.autoStopped)
        #expect(session.flags.contains(.stoppedAutomatically))
        #expect(session.syncState == .local)
    }

    @Test("Before the closing time, nothing is stopped")
    func autoStopLeavesRunningSessionsAlone() throws {
        let fixture = try makeFixture(now: date(15, 14))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)

        fixture.clock.now = date(15, 20, 59)
        let stopped = try fixture.store.applyAutoStop(closing: closing)

        #expect(stopped == 0)
        #expect(session.status == .running)
    }

    @Test("Someone who starts after the closing time keeps working")
    func autoStopSkipsSessionStartedAfterClosing() throws {
        let fixture = try makeFixture(now: date(15, 21, 30))
        let member = try makeMember(fixture.context)
        let session = try fixture.store.start(member: member)

        fixture.clock.now = date(15, 23)
        let stopped = try fixture.store.applyAutoStop(closing: closing)

        #expect(stopped == 0)
        #expect(session.status == .running)
    }

    // MARK: - Settings

    @Test("Settings are created once, with the documented defaults")
    func settingsAreCreatedOnce() throws {
        let fixture = try makeFixture(now: date(15, 9))

        let first = try fixture.store.settings()
        first.clubName = "Zweefvliegclub Voorbeeld"
        let second = try fixture.store.settings()

        #expect(first.closingHour == 21)
        #expect(first.closingMinute == 0)
        #expect(second.clubName == "Zweefvliegclub Voorbeeld")
        #expect(first.closingComponents == DateComponents(hour: 21, minute: 0))
    }

    // MARK: - Reading

    @Test("A day shows only the sessions that started that day")
    func sessionsOfADay() throws {
        let fixture = try makeFixture(now: date(14, 9))
        let jan = try makeMember(fixture.context, id: 1)
        let koen = try makeMember(fixture.context, id: 2)

        let yesterday = try fixture.store.start(member: jan)
        fixture.clock.now = date(14, 10)
        try fixture.store.stop(yesterday)

        fixture.clock.now = date(15, 9)
        let today = try fixture.store.start(member: koen)
        fixture.clock.now = date(15, 10)
        try fixture.store.stop(today)

        #expect(try fixture.store.sessions(onDayOf: date(15, 12)).map(\.id) == [today.id])
        #expect(try fixture.store.sessions(onDayOf: date(14, 12)).map(\.id) == [yesterday.id])
    }
}
