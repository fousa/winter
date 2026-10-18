import Foundation

/// Everything needed to reach zweef.app, as one value that can cross threads.
///
/// A snapshot rather than a reference to ``AppConfiguration``: the sync engine
/// runs on its own executor and must not reach back into main-actor state, and
/// a value makes "which settings was this upload sent with" answerable.
struct ConnectionSettings: Equatable, Sendable {
    /// The club's schema name, from its zweef.app settings.
    var clubSchema: String
    /// Read from the Keychain at snapshot time; never logged.
    var apiKey: String?

    /// Whether these settings are complete enough to send a request.
    var isUsable: Bool {
        !clubSchema.trimmed.isEmpty && apiKey?.isEmpty == false
    }

    /// The transport these settings describe, or nil when they are incomplete.
    func makeTransport() -> ZweefTransport? {
        guard isUsable, let key = apiKey else { return nil }
        return ZweefTransport(clubSchema: clubSchema.trimmed, apiKey: key)
    }

    /// The API these settings describe, or the unconfigured one.
    func makeAPI(session: URLSession = .shared) -> any ZweefAPI {
        guard let transport = makeTransport() else { return UnconfiguredZweefAPI() }
        return ZweefClient(transport: transport, session: session)
    }
}

/// Hands the current connection to whoever needs it, including the sync engine
/// on its own executor.
///
/// It exists because the connection changes while the app runs — the setup
/// assistant creates it, the settings screen edits it — and an engine that
/// captured an API at launch would keep using a key the club has rotated.
/// Read on every sync run instead.
///
/// `@unchecked Sendable` with a lock: one small value behind one mutex, read
/// from the sync engine's executor and written from the main actor.
final class ConnectionProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var settings: ConnectionSettings?
    private let session: URLSession

    init(settings: ConnectionSettings? = nil, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    /// Replaces the connection. Called after setup and after any change in
    /// settings, so the next sync run uses the new key.
    func update(_ settings: ConnectionSettings?) {
        lock.withLock { self.settings = settings }
    }

    var current: ConnectionSettings? {
        lock.withLock { settings }
    }

    /// What the sync engine calls at the start of every run.
    func api() -> any ZweefAPI {
        guard let settings = current else { return UnconfiguredZweefAPI() }
        return settings.makeAPI(session: session)
    }
}

@MainActor
extension ConnectionSettings {
    /// Reads the current configuration and its key into a snapshot.
    init(configuration: AppConfiguration, secrets: some SecretStore) {
        self.init(
            clubSchema: configuration.clubSchema,
            apiKey: secrets.secret(for: .apiKey)
        )
    }
}

/// What "Test connection" found.
///
/// Reported as a value so the setup assistant can show exactly what worked:
/// a club that sees its period number knows the key is right, even when the
/// club name comes back empty because `club.json` answers 500 (ADR 0012).
struct ConnectionTestResult: Equatable, Sendable {
    /// The active maintenance period, if there is one to find.
    var periodId: Int?
    /// The club's name, when zweef.app gives one.
    var clubName: String?
    /// How many registrations the period already holds — proof we read real
    /// data rather than an empty 200.
    var registrationCount: Int
}

/// Tries a connection without changing anything.
///
/// Uses `current/hours.json` rather than the documented `periods.json`, which
/// answers 404 for a real club (`docs/zweef-api.md`). The club name is a
/// bonus: its endpoint is the least dependable of the set, so a failure there
/// is not a failed test.
enum ConnectionTester {
    static func test(_ api: any ZweefAPI) async throws -> ConnectionTestResult {
        let hours = try await api.currentPeriodHours()
        let clubName = try? await api.club().name

        return ConnectionTestResult(
            periodId: hours.first?.periodId,
            clubName: clubName,
            registrationCount: hours.count
        )
    }
}
