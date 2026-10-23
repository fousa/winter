import Foundation
import SwiftData

/// Everything one mode of the app runs on: the database, the configuration,
/// the secrets, the connection and the sync stack.
///
/// One value per mode, so the demo (ADR 0021) can be swapped in and out while
/// the app runs without a single real object noticing: the demo gets its own
/// in-memory database, its own UserDefaults suite, no Keychain, and a fake
/// zweef.app that answers with the sample club and stores nothing.
@MainActor
final class AppEnvironment {
    let container: ModelContainer
    let configuration: AppConfiguration
    let secrets: any SecretStore
    let connection: ConnectionProvider
    let sync: SyncCoordinator
    let autoStop: AutoStopService
    /// Set for the demo; the home screen then shows that it is one.
    let isDemo: Bool

    private init(
        container: ModelContainer,
        configuration: AppConfiguration,
        secrets: any SecretStore,
        connection: ConnectionProvider,
        isDemo: Bool
    ) {
        self.container = container
        self.configuration = configuration
        self.secrets = secrets
        self.connection = connection
        self.isDemo = isDemo

        let store = SessionStore(context: container.mainContext)
        let autoStop = AutoStopService(store: store) { try? store.settings() }
        self.autoStop = autoStop
        self.sync = SyncCoordinator(
            engine: SyncEngine(container: container, apiProvider: { connection.api() }),
            connectivity: ConnectivityMonitor(),
            autoStop: autoStop
        )
    }

    /// The real app: the database on disk, the Keychain, the club's own
    /// connection.
    static func live() -> AppEnvironment {
        let container: ModelContainer
        do {
            container = try WinterSchema.container()
        } catch {
            // Nothing can be recorded without a store, and silently running on
            // an in-memory one would lose a member's hours without telling
            // anyone — which is the one thing this app must never do.
            fatalError("Could not open the Winter database: \(error)")
        }
        let configuration = AppConfiguration()
        let secrets = KeychainSecretStore()
        // Read once here and updated whenever the settings change, so the sync
        // engine always uses the current token.
        let connection = ConnectionProvider(
            settings: ConnectionSettings(configuration: configuration, secrets: secrets)
        )
        return AppEnvironment(
            container: container,
            configuration: configuration,
            secrets: secrets,
            connection: connection,
            isDemo: false
        )
    }

    /// The admin code of the demo's settings, shown on the setup page that
    /// starts the demo and given to App Review.
    static let demoAdminCode = "123456"

    /// The sample club, for App Review and for anyone curious (ADR 0021):
    /// two timers running and a few finished sessions, with nothing written to
    /// disk, the Keychain or zweef.app. Leaving the demo, or quitting the app,
    /// throws it all away.
    static func demo() -> AppEnvironment? {
        sampleClub(runningSessionCount: 2, withFinishedSessions: true, isDemo: true)
    }

    /// The same sample club, opened by the debug launch arguments `-sampleClub`
    /// and `-sampleScreen` (CONTRIBUTING.md).
    static func sampleClub(runningSessionCount: Int, withFinishedSessions: Bool, isDemo: Bool) -> AppEnvironment? {
        let suite = "app.winter.sample-club"
        guard let container = try? (withFinishedSessions
            ? SampleData.finishedSessionsContainer(runningSessionCount: runningSessionCount)
            : SampleData.container(runningSessionCount: runningSessionCount)),
              let defaults = UserDefaults(suiteName: suite)
        else { return nil }
        defaults.removePersistentDomain(forName: suite)

        // The fake zweef.app knows the sample club's period, so "Upload" goes
        // through — into the fake, not into zweef.app.
        if let settings = try? container.mainContext.fetch(FetchDescriptor<AppSettings>()).first {
            settings.activePeriodId = 1
            settings.lastRefreshAt = .now
            try? container.mainContext.save()
        }

        let configuration = AppConfiguration(defaults: defaults)
        configuration.clubSchema = "sampleclub"
        configuration.hasCompletedSetup = true
        let secrets = InMemorySecretStore([.apiKey: "sample"])
        try? AdminCodeVerifier(secrets: secrets, configuration: configuration).setCode(demoAdminCode)

        let api = FakeZweefAPI.sampleClub()
        let connection = ConnectionProvider(fixed: api)
        return AppEnvironment(
            container: container,
            configuration: configuration,
            secrets: secrets,
            connection: connection,
            isDemo: isDemo
        )
    }
}

extension FakeZweefAPI {
    /// A fake zweef.app that answers with the sample club's own members and
    /// material, so a refresh in the demo changes nothing it should not.
    static func sampleClub() -> FakeZweefAPI {
        FakeZweefAPI(
            club: .success(ZweefClub(name: "Zweefvliegclub Voorbeeld")),
            accounts: .success(SampleData.members.map {
                ZweefAccount(id: $0.id, firstName: $0.first, lastName: $0.last, isActive: true)
            }),
            material: .success(SampleData.material.map { item in
                ZweefMaterial(
                    id: item.id,
                    name: item.name,
                    type: item.type.isEmpty ? nil : item.type,
                    category: item.kind.rawValue,
                    kistConfiguration: item.isGlider ? "Glider" : nil,
                    kistCategory: item.kind == .flying ? "club" : nil,
                    status: "in bedrijf",
                    isVisible: true,
                    order: nil
                )
            }),
            hours: .success([])
        )
    }
}
