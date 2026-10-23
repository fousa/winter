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
}
