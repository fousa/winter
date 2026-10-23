import BackgroundTasks
import SwiftData
import SwiftUI

/// The app's entry point: builds the one model container, the configuration and
/// the sync stack, and wires the triggers that keep hours moving.
@main
struct WinterApp: App {
    /// Must match the `BGTaskSchedulerPermittedIdentifiers` entry in
    /// `App/Info.plist`, or the system refuses every request.
    ///
    /// `nonisolated` because the background task scheduling happens off the
    /// main actor.
    nonisolated static let refreshTaskIdentifier = "app.winter.refresh"

    private let container: ModelContainer
    private let configuration: AppConfiguration
    private let secrets: any SecretStore
    private let connection: ConnectionProvider

    @State private var sync: SyncCoordinator
    @State private var autoStop: AutoStopService

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container: ModelContainer
        let configuration: AppConfiguration
        let secrets: any SecretStore
        let connection: ConnectionProvider

        if let sample = Self.sampleClubLaunch() {
            (container, configuration, secrets, connection) = sample
        } else {
            do {
                container = try WinterSchema.container()
            } catch {
                // Nothing can be recorded without a store, and silently running
                // on an in-memory one would lose a member's hours without
                // telling anyone — which is the one thing this app must never
                // do.
                fatalError("Could not open the Winter database: \(error)")
            }
            configuration = AppConfiguration()
            secrets = KeychainSecretStore()
            // Read once at launch and updated whenever the settings change, so
            // the sync engine always uses the current token.
            connection = ConnectionProvider(
                settings: ConnectionSettings(configuration: configuration, secrets: secrets)
            )
        }
        self.container = container
        self.configuration = configuration
        self.secrets = secrets
        self.connection = connection

        let store = SessionStore(context: container.mainContext)
        let autoStop = AutoStopService(store: store) { try? store.settings() }

        let engine = SyncEngine(
            container: container,
            apiProvider: { connection.api() }
        )

        self.autoStop = autoStop
        self.sync = SyncCoordinator(
            engine: engine,
            connectivity: ConnectivityMonitor(),
            autoStop: autoStop
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(configuration: configuration, secrets: secrets, connection: connection)
                .environment(sync)
                .task { await sync.watchConnectivity() }
                .task { await autoStop.runWhileActive() }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await sync.appBecameActive() }
            case .background:
                scheduleBackgroundRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(WinterApp.refreshTaskIdentifier)) {
            // Best effort: the system decides whether this ever runs. Hours are
            // safe on the device either way; this only shortens the wait.
            await sync.backgroundRefresh()
            scheduleBackgroundRefresh()
        }
    }

    /// Debug builds only: `-sampleClub 3` launches straight into the home
    /// screen of the fictional club with three timers running, in memory and
    /// with no connection, so a screen can be looked at on a simulator without
    /// a zweef.app key. Nothing is written to disk and nothing is uploaded.
    ///
    /// With `-sampleScreen sync` or `-sampleScreen stop` the club also has
    /// finished sessions, and the home screen opens that screen on launch.
    private static func sampleClubLaunch() -> (ModelContainer, AppConfiguration, any SecretStore, ConnectionProvider)? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-sampleClub") else { return nil }
        let running = arguments.indices.contains(index + 1) ? Int(arguments[index + 1]) ?? 0 : 0

        let wantsFinishedHours = arguments.contains("-sampleScreen")
        guard let container = try? (wantsFinishedHours
            ? SampleData.finishedSessionsContainer(runningSessionCount: running)
            : SampleData.container(runningSessionCount: running)),
              let defaults = UserDefaults(suiteName: "app.winter.sample-club")
        else { return nil }
        defaults.removePersistentDomain(forName: "app.winter.sample-club")
        let configuration = AppConfiguration(defaults: defaults)
        configuration.clubSchema = "exampleclub"
        configuration.hasCompletedSetup = true
        let secrets = InMemorySecretStore([.apiKey: "sample", .adminCode: "sample"])
        return (container, configuration, secrets, ConnectionProvider())
        #else
        return nil
        #endif
    }

    private nonisolated func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        // Not sooner than an hour: a club's hours are not urgent, and asking
        // too often is how an app loses its background budget.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
