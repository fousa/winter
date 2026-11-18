import Foundation
import SwiftData
import Testing

@testable import Winter

@MainActor
@Suite("Home model")
struct HomeModelTests {
    /// The container is returned too and held by the test: a context
    /// outliving its container crashes the test host.
    private func makeStore() throws -> (ModelContainer, SessionStore, Member) {
        let container = try WinterSchema.inMemoryContainer()
        let member = Member(zweefId: 1, firstName: "Jan", lastName: "Verhoeven")
        container.mainContext.insert(member)
        try container.mainContext.save()
        return (container, SessionStore(context: container.mainContext), member)
    }

    @Test("Starting from a search closes it, so the next person sees everyone")
    func startEndsTheSearch() throws {
        let (container, store, member) = try makeStore()
        defer { withExtendedLifetime(container) {} }
        let model = HomeModel()
        model.searchText = "Jan"
        model.isSearching = true

        model.start(member: member, store: store)

        #expect(model.searchText.isEmpty)
        #expect(!model.isSearching)
    }

    @Test("Stopping from a search closes it too")
    func stopEndsTheSearch() throws {
        let (container, store, member) = try makeStore()
        defer { withExtendedLifetime(container) {} }
        let model = HomeModel()
        let session = try store.start(member: member)
        model.searchText = "Jan"
        model.isSearching = true

        model.stop(session, member: member, material: nil, store: store)

        #expect(model.searchText.isEmpty)
        #expect(!model.isSearching)
    }

    @Test("Pausing and resuming close the sheet and leave the timer where it belongs")
    func pauseAndResume() throws {
        let (container, store, member) = try makeStore()
        defer { withExtendedLifetime(container) {} }
        let model = HomeModel()
        let session = try store.start(member: member)
        model.route = .stop(sessionId: session.id)

        model.pause(session, store: store)

        #expect(session.isPaused)
        #expect(model.route == nil)

        model.route = .stop(sessionId: session.id)
        model.resume(session, store: store)

        #expect(!session.isPaused)
        #expect(session.status == .running)
        #expect(model.route == nil)
    }

    @Test("Stopping a forgotten break with its real length saves the time since, too")
    func stopWithACountedBreak() throws {
        let container = try WinterSchema.inMemoryContainer()
        defer { withExtendedLifetime(container) {} }
        let member = Member(zweefId: 1, firstName: "Jan", lastName: "Verhoeven")
        container.mainContext.insert(member)
        // 09:00 start, on a break since 12:00, noticed at 16:00.
        let nine = Date(timeIntervalSince1970: 1_760_000_000)
        var now = nine
        let store = SessionStore(context: container.mainContext, now: { now })
        let session = try store.start(member: member)
        now = nine.addingTimeInterval(3 * 3600)
        try store.pause(session)
        now = nine.addingTimeInterval(7 * 3600)

        HomeModel().stop(session, member: member, material: nil, countedBreak: 30, store: store)

        #expect(session.status == .completed)
        #expect(session.stop == now)
        #expect(session.minutes == 7 * 60 - 30)
        #expect(!session.endedOnBreak)
    }

    @Test("Stopping a paused timer without a length saves up to the break, no further")
    func stopOnABreak() throws {
        let container = try WinterSchema.inMemoryContainer()
        defer { withExtendedLifetime(container) {} }
        let member = Member(zweefId: 1, firstName: "Jan", lastName: "Verhoeven")
        container.mainContext.insert(member)
        let nine = Date(timeIntervalSince1970: 1_760_000_000)
        var now = nine
        let store = SessionStore(context: container.mainContext, now: { now })
        let session = try store.start(member: member)
        now = nine.addingTimeInterval(3 * 3600)
        try store.pause(session)
        now = nine.addingTimeInterval(7 * 3600)

        HomeModel().stop(session, member: member, material: nil, store: store)

        #expect(session.minutes == 3 * 60)
        #expect(session.endedOnBreak)
    }
}
