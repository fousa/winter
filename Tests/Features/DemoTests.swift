import Foundation
import SwiftData
import Testing

@testable import Winter

/// The demo is what App Review sees (ADR 0021): it has to work end to end,
/// and it must not touch anything real.
@MainActor
@Suite("Demo")
struct DemoTests {
    @Test("The demo opens on a set-up sample club, with timers running")
    func opensOnTheSampleClub() throws {
        let demo = try #require(AppEnvironment.demo())

        #expect(demo.isDemo)
        let isSetUp = demo.configuration.isComplete(secrets: demo.secrets)
        #expect(isSetUp)
        let sessions = try demo.container.mainContext.fetch(FetchDescriptor<WorkSession>())
        #expect(sessions.filter { $0.status == .running }.count == 2)
        #expect(try demo.container.mainContext.fetchCount(FetchDescriptor<Material>()) == SampleData.material.count)
    }

    @Test("Its settings open with the code it shows")
    func adminCodeWorks() throws {
        let demo = try #require(AppEnvironment.demo())
        let verifier = AdminCodeVerifier(secrets: demo.secrets, configuration: demo.configuration)
        try verifier.verify(AppEnvironment.demoAdminCode)
    }

    @Test("Upload goes through, into the fake zweef.app")
    func uploadWorks() async throws {
        let demo = try #require(AppEnvironment.demo())

        await demo.sync.uploadNow()

        let sessions = try demo.container.mainContext.fetch(FetchDescriptor<WorkSession>())
        let finished = sessions.filter { $0.status == .completed }
        #expect(!finished.isEmpty)
        #expect(finished.allSatisfy { $0.syncState == .uploaded })
    }

    @Test("Refreshing in the demo keeps the sample club as it is")
    func refreshKeepsTheSampleClub() async throws {
        let demo = try #require(AppEnvironment.demo())

        await demo.sync.refreshMembers()

        let members = try demo.container.mainContext.fetch(FetchDescriptor<Member>())
        #expect(Set(members.map(\.zweefId)) == Set(SampleData.members.map(\.id)))
        let material = try demo.container.mainContext.fetch(FetchDescriptor<Material>())
        #expect(Set(material.map(\.zweefId)) == Set(SampleData.material.map(\.id)))
    }

    @Test("The demo never reads or writes the real app's settings")
    func keepsItsOwnSettings() throws {
        let demo = try #require(AppEnvironment.demo())
        #expect(demo.configuration.clubSchema == "sampleclub")
        #expect(UserDefaults.standard.string(forKey: "clubSchema") != "sampleclub")
    }
}
