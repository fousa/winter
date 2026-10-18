import Foundation

/// Talks to zweef.app over HTTPS, through whichever ``Transport`` the club
/// configured.
///
/// It knows nothing about proxy versus direct mode, nothing about SwiftData,
/// and holds no state: handed a transport and a session, it turns endpoints
/// into typed values or a ``ZweefError``.
struct ZweefClient: ZweefAPI {
    private let transport: any Transport
    private let session: URLSession

    init(transport: any Transport, session: URLSession = .shared) {
        self.transport = transport
        self.session = session
    }

    /// zweef.app is consistently snake_case, so one strategy covers every DTO.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    // MARK: - Reading

    func club() async throws -> ZweefClub {
        try await get(Endpoint(path: "/club.json"))
    }

    func accounts(inactiveOnly: Bool = false) async throws -> [ZweefAccount] {
        try await get(Endpoint(
            path: "/accounts.json",
            query: inactiveOnly ? ["inactive": "1"] : [:]
        ))
    }

    func material() async throws -> [ZweefMaterial] {
        try await get(Endpoint(path: "/material.json"))
    }

    func currentPeriodHours() async throws -> [ZweefMaintenanceHour] {
        try await get(Endpoint(path: "/maintenance-hours/current/hours.json"))
    }

    /// The active period's id, read off the registrations in it.
    ///
    /// `GET /maintenance-hours/periods.json` is the documented way and would be
    /// the obvious one, but it answers 404 for a real club, so the app derives
    /// the period from `current/hours.json` instead. Returns nil when the
    /// period has no registrations yet — the first upload of a brand-new period
    /// then has nothing to go on, which is a question for zweef.app
    /// (`docs/zweef-api.md`).
    func activePeriodId() async throws -> Int? {
        try await currentPeriodHours().first?.periodId
    }

    // MARK: - Writing

    func create(_ draft: MaintenanceHourDraft) async throws -> CreatedRegistration {
        let body: Data
        do {
            body = try Self.encoder.encode(draft)
        } catch {
            throw ZweefError.decoding("Could not encode the registration: \(error)")
        }

        let data = try await perform(Endpoint(method: .post, path: "/maintenance-hours.json", body: body))

        // An empty or unexpected body is not a failure: the registration is
        // there, we just do not know its id. Dedup uses the description tag.
        guard !data.isEmpty else { return CreatedRegistration(id: nil) }
        return (try? Self.decoder.decode(CreatedRegistration.self, from: data)) ?? CreatedRegistration(id: nil)
    }

    // MARK: - Plumbing

    private func get<Value: Decodable>(_ endpoint: Endpoint) async throws -> Value {
        let data = try await perform(endpoint)
        do {
            return try Self.decoder.decode(Value.self, from: data)
        } catch {
            throw ZweefError.decoding("\(endpoint.path): \(error)")
        }
    }

    /// Sends the request and turns the status code into something actionable.
    private func perform(_ endpoint: Endpoint) async throws -> Data {
        let request = try transport.request(for: endpoint)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            // No connection, a timeout, DNS: all the same to the app, which
            // simply tries again later.
            throw ZweefError.unreachable
        }

        guard let http = response as? HTTPURLResponse else {
            throw ZweefError.decoding("\(endpoint.path): not an HTTP response")
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401, 403:
            throw ZweefError.notAuthorised
        case 400...499:
            throw ZweefError.rejected(status: http.statusCode, reason: Self.reason(from: data))
        default:
            throw ZweefError.server(status: http.statusCode)
        }
    }

    /// A short, human-readable reason from an error body, for the sync screen.
    ///
    /// zweef.app answers errors with HTML as often as with JSON, so anything
    /// that is not a tidy message is dropped rather than shown to a member.
    private static func reason(from data: Data) -> String? {
        guard !data.isEmpty,
              let text = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              !text.lowercased().hasPrefix("<")
        else { return nil }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["detail", "error", "message"] {
                if let message = json[key] as? String, !message.isEmpty { return message }
            }
            return nil
        }

        return String(text.prefix(200))
    }
}
