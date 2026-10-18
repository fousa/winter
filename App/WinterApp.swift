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
        do {
            container = try WinterSchema.container()
        } catch {
            // Nothing can be recorded without a store, and silently running on
            // an in-memory one would lose a member's hours without telling
            // anyone — which is the one thing this app must never do.
            fatalError("Could not open the Winter database: \(error)")
        }
        self.container = container

        let configuration = AppConfiguration()
        let secrets = KeychainSecretStore()
        // Read once at launch and updated whenever the settings change, so the
        // sync engine always uses the current token.
        let connection = ConnectionProvider(
            settings: ConnectionSettings(configuration: configuration, secrets: secrets)
        )
        self.configuration = configuration
        self.secrets = secrets
        self.connection = connection

        let store = SessionStore(context: container.mainContext)
        let autoStop = AutoStopService(store: store) { try? store.settings() }

        let engine = SyncEngine(
            container: container,
            apiProvider: { connection.api() },
            // Resolved per call, not captured: a club can change the language
            // its hours are written in, and the next upload should use it
            // (ADR 0010).
            flagLabel: { flag in
                let code = MainActor.assumeIsolated { (try? store.settings())?.reportingLanguageCode } ?? "en"
                return ReportingLanguage(code: code).label(for: flag)
            }
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

    private nonisolated func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        // Not sooner than an hour: a club's hours are not urgent, and asking
        // too often is how an app loses its background budget.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
