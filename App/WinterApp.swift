import BackgroundTasks
import SwiftData
import SwiftUI

/// The app's entry point: builds the one model container, the sync stack, and
/// the triggers that keep hours moving.
@main
struct WinterApp: App {
    /// The background refresh task's identifier, which must match the
    /// `BGTaskSchedulerPermittedIdentifiers` entry in the Info.plist.
    static let refreshTaskIdentifier = "app.winter.refresh"

    private let container: ModelContainer
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

        let store = SessionStore(context: container.mainContext)
        let autoStop = AutoStopService(store: store) {
            try? store.settings()
        }

        // The reporting language is club data, so it is read from the store
        // rather than from the device: the board gets one consistent list
        // whoever stopped the timer (ADR 0010).
        let language = ReportingLanguage(code: (try? store.settings())?.reportingLanguageCode ?? "en")

        let engine = SyncEngine(
            container: container,
            api: WinterApp.makeAPI(),
            flagLabel: { flag in language.label(for: flag) }
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
            RootView()
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
            await scheduleBackgroundRefreshFromBackground()
        }
    }

    /// Until the setup assistant exists (phase 4b), the app has no configured
    /// connection, so it runs against the fake and keeps every hour local.
    ///
    /// Replacing this with a real transport built from the Keychain and
    /// `AppConfiguration` is the first thing phase 4b does.
    private static func makeAPI() -> any ZweefAPI {
        FakeZweefAPI(
            club: .failure(.server(status: 500)),
            accounts: .success([]),
            material: .success([]),
            hours: .success([]),
            create: .failure(.unreachable)
        )
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        // Not sooner than an hour: a club's hours are not urgent, and asking
        // too often is how an app loses its background budget.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func scheduleBackgroundRefreshFromBackground() async {
        scheduleBackgroundRefresh()
    }
}
