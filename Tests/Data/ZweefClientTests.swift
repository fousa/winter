import Foundation
import Testing

@testable import Winter

@Suite("zweef.app client")
struct ZweefClientTests {
    /// A fictional schema: no real club's name belongs in the repository.
    private let transport = DirectTransport(clubSchema: "exampleclub", apiKey: "test-key")

    /// A client wired to its own stub, so parallel tests cannot answer each
    /// other's requests.
    private func makeClient(
        status: Int = 200,
        fixture: String? = nil,
        body: Data = Data(),
        headers: [String: String] = ["Content-Type": "application/json"],
        error: (any Error)? = nil,
        transport: (any Transport)? = nil
    ) throws -> (client: ZweefClient, stub: StubURLProtocol.Stub) {
        let payload = try fixture.map { try Fixture.data($0) } ?? body
        let stub = StubURLProtocol.stub { _ in
            if let error { throw error }
            return (status, headers, payload)
        }
        return (ZweefClient(transport: transport ?? self.transport, session: stub.session), stub)
    }

    // MARK: - Decoding the real shapes

    @Test("Accounts decode from a real response, ignoring the sixty keys we do not want")
    func decodesAccounts() async throws {
        let accounts = try await makeClient(fixture: "accounts.json").client.accounts(inactiveOnly: false)

        #expect(accounts.count == 4)
        #expect(accounts[0] == ZweefAccount(id: 101, firstName: "Jan", lastName: "Verhoeven", isActive: true))
        #expect(accounts.map(\.isActive) == [true, true, true, true])
    }

    @Test("Accents in a member's name survive decoding")
    func decodesAccentedNames() async throws {
        let accounts = try await makeClient(fixture: "accounts.json").client.accounts(inactiveOnly: false)
        #expect(accounts.last?.firstName == "Émile")
    }

    @Test("?inactive=1 returns only inactive members, so getting everybody takes two calls")
    func decodesInactiveAccounts() async throws {
        let (client, stub) = try makeClient(fixture: "accounts-inactive.json")

        let accounts = try await client.accounts(inactiveOnly: true)

        #expect(accounts.count == 1)
        #expect(accounts[0].isActive == false)
        #expect(stub.requests.first?.url?.query == "inactive=1")
    }

    @Test("Material decodes, including entries without a configuration")
    func decodesMaterial() async throws {
        let material = try await makeClient(fixture: "material.json").client.material()

        #expect(material.count == 5)
        #expect(material[0].name == "ASK 21")
        #expect(material[0].isGlider)
        #expect(material[0].isAircraft)
        // A private glider whose configuration is an empty string is still an
        // aircraft, just not a known glider.
        #expect(material[2].isAircraft)
        #expect(!material[2].isGlider)
        // The winch has no configuration key at all, and a null kist_id.
        #expect(material[3].kistConfiguration == nil)
        #expect(!material[3].isAircraft)
    }

    @Test("Registrations decode, with their status and the dedup tag intact")
    func decodesMaintenanceHours() async throws {
        let hours = try await makeClient(fixture: "maintenance-hours.json").client.currentPeriodHours()

        #expect(hours.count == 3)
        #expect(hours[0].id == 11)
        #expect(hours[0].periodId == 1)
        #expect(hours[0].hours == 2.0)
        #expect(hours[0].status == "in_aanvraag")
        #expect(hours[1].status == "geaccepteerd")
        #expect(hours[1].materialId == nil)
        #expect(hours[0].description.contains("[ou:a1b2c3d4]"))
    }

    @Test("The active period is read off the registrations, because periods.json 404s")
    func readsActivePeriodFromHours() async throws {
        let periodId = try await makeClient(fixture: "maintenance-hours.json").client.activePeriodId()
        #expect(periodId == 1)
    }

    @Test("A period with no registrations yet leaves the app without an id")
    func activePeriodIsNilWhenThereAreNoHours() async throws {
        let periodId = try await makeClient(body: Data("[]".utf8)).client.activePeriodId()
        #expect(periodId == nil)
    }

    @Test("A club response without a name does not stop the app")
    func decodesClubWithoutName() async throws {
        let club = try await makeClient(body: Data("{}".utf8)).client.club()
        #expect(club.name == nil)
    }

    // MARK: - Requests

    @Test("Direct mode sends the API key to the club's own API root")
    func directTransportSendsApiKey() async throws {
        let (client, stub) = try makeClient(fixture: "material.json")

        _ = try await client.material()

        let request = try #require(stub.requests.first)
        #expect(request.url?.absoluteString == "https://admin.gliding.app/club/exampleclub/api/material.json")
        #expect(request.value(forHTTPHeaderField: "X-API-KEY") == "test-key")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Proxy mode sends the device token and never the API key")
    func proxyTransportSendsDeviceToken() async throws {
        let proxy = ProxyTransport(
            baseURL: URL(string: "https://winter-proxy.example.workers.dev")!,
            deviceToken: "device-token"
        )
        let (client, stub) = try makeClient(fixture: "material.json", transport: proxy)

        _ = try await client.material()

        let request = try #require(stub.requests.first)
        #expect(request.url?.absoluteString == "https://winter-proxy.example.workers.dev/material.json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer device-token")
        #expect(request.value(forHTTPHeaderField: "X-API-KEY") == nil)
    }

    @Test("Creating a registration posts the fields zweef.app expects, in snake_case")
    func createPostsSnakeCase() async throws {
        let (client, stub) = try makeClient(status: 201, body: Data(#"{"id": 42}"#.utf8))
        let draft = MaintenanceHourDraft(
            periodId: 1,
            userId: 101,
            userName: "Jan Verhoeven",
            date: "2026-10-15",
            hours: 2.3,
            materialId: 1,
            workorderId: nil,
            isPrivate: false,
            category: "",
            subCategory: "",
            project: "Glider",
            description: "Glider · ASK 21 · 09:12–11:30 [ou:a1b2c3d4]",
            status: "in_aanvraag"
        )

        let created = try await client.create(draft)

        #expect(created.id == 42)

        let request = try #require(stub.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let data = try #require(request.capturedBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["period_id"] as? Int == 1)
        #expect(body["user_id"] as? Int == 101)
        #expect(body["user_name"] as? String == "Jan Verhoeven")
        #expect(body["date"] as? String == "2026-10-15")
        #expect(body["hours"] as? Double == 2.3)
        #expect(body["material_id"] as? Int == 1)
        #expect(body["is_private"] as? Bool == false)
        #expect(body["category"] as? String == "")
        #expect(body["sub_category"] as? String == "")
        #expect(body["status"] as? String == "in_aanvraag")
        #expect(body["workorder_id"] == nil)
    }

    @Test("An id comes back whatever shape it arrives in", arguments: [
        #"{"id": 7}"#,
        #"{"data": {"id": 7}}"#,
        #"{"maintenance_hour": {"id": 7}}"#,
        "7",
    ])
    func acceptsEveryPlausibleCreateResponse(json: String) async throws {
        let (client, _) = try makeClient(body: Data(json.utf8))
        let created = try await client.create(FakeDraft.minimal)
        #expect(created.id == 7)
    }

    @Test("A response with no id is still a success, because dedup uses the tag")
    func createWithoutIdIsNotAFailure() async throws {
        let (client, _) = try makeClient(body: Data(), headers: [:])
        let created = try await client.create(FakeDraft.minimal)
        #expect(created.id == nil)
    }

    // MARK: - Errors

    @Test("A revoked token stops syncing instead of retrying", arguments: [401, 403])
    func unauthorisedIsNotRetried(status: Int) async throws {
        let (client, _) = try makeClient(status: status, body: Data(#"{"detail":"nope"}"#.utf8))

        await #expect(throws: ZweefError.notAuthorised) {
            try await client.material()
        }
        #expect(ZweefError.notAuthorised.isRetryable == false)
    }

    @Test("A 4xx on a registration is a rejection, with its reason")
    func rejectionCarriesItsReason() async throws {
        let (client, _) = try makeClient(
            status: 422,
            body: Data(#"{"detail": "Member is not active"}"#.utf8)
        )

        await #expect(throws: ZweefError.rejected(status: 422, reason: "Member is not active")) {
            try await client.create(FakeDraft.minimal)
        }
    }

    @Test("An HTML error page is never shown to a member as a reason")
    func htmlErrorBodiesAreDropped() async throws {
        let (client, _) = try makeClient(
            status: 400,
            body: Data("<!doctype html><html>Server Error</html>".utf8),
            headers: ["Content-Type": "text/html"]
        )

        await #expect(throws: ZweefError.rejected(status: 400, reason: nil)) {
            try await client.create(FakeDraft.minimal)
        }
    }

    @Test("A 500 — which club.json really does return — is retryable")
    func serverErrorsAreRetryable() async throws {
        let (client, _) = try makeClient(
            status: 500,
            body: Data("<html>Server Error (500)</html>".utf8),
            headers: ["Content-Type": "text/html"]
        )

        await #expect(throws: ZweefError.server(status: 500)) {
            try await client.club()
        }
        #expect(ZweefError.server(status: 500).isRetryable)
    }

    @Test("No connection is retryable, and says nothing alarming")
    func networkFailuresAreRetryable() async throws {
        let (client, _) = try makeClient(error: URLError(.notConnectedToInternet))

        await #expect(throws: ZweefError.unreachable) {
            try await client.material()
        }
        #expect(ZweefError.unreachable.isRetryable)
    }

    @Test("A shape we do not recognise is reported, not swallowed")
    func decodingFailuresSurface() async throws {
        let (client, _) = try makeClient(body: Data(#"[{"unexpected": true}]"#.utf8))

        await #expect(throws: ZweefError.self) {
            try await client.material()
        }
    }
}

/// A draft with the bare minimum filled in, for tests that only care about the
/// request or the response.
enum FakeDraft {
    static let minimal = MaintenanceHourDraft(
        periodId: 1,
        userId: 1,
        userName: "Test Member",
        date: "2026-10-15",
        hours: 1.0,
        materialId: nil,
        workorderId: nil,
        isPrivate: false,
        category: "",
        subCategory: "",
        project: "",
        description: "test",
        status: "in_aanvraag"
    )
}
