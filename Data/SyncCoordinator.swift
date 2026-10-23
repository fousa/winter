import Foundation
import Observation
import SwiftData

/// The one object the screens talk to about syncing.
///
/// It owns the ``SyncEngine`` and the triggers around it — connectivity coming
/// back, the app becoming active, the background task, the button on the sync
/// screen — and publishes just enough state for the UI to be honest about what
/// is happening. The engine itself stays free of SwiftUI.
@MainActor
@Observable
final class SyncCoordinator {
    /// Whether a run is in progress, so a button can show a spinner and not be
    /// pressed twice.
    private(set) var isSyncing = false

    /// What the last run did, for the sync screen.
    private(set) var lastOutcome: SyncEngine.Outcome?

    /// Whether the device can reach anything at all.
    private(set) var isConnected: Bool

    private let engine: SyncEngine
    private let connectivity: any ConnectivityReporting
    private let autoStop: AutoStopService

    init(engine: SyncEngine, connectivity: any ConnectivityReporting, autoStop: AutoStopService) {
        self.engine = engine
        self.connectivity = connectivity
        self.autoStop = autoStop
        self.isConnected = connectivity.isCurrentlyConnected
    }

    /// Watches the network for as long as the app is on screen.
    ///
    /// A sync fires when the path *becomes* satisfied rather than on every
    /// update, so a flapping club wifi does not mean a run per flap.
    func watchConnectivity() async {
        for await connected in connectivity.changes() {
            let wasConnected = isConnected
            isConnected = connected
            if connected, !wasConnected {
                await sync(.connectivityReturned)
            }
        }
    }

    /// Stops forgotten timers and syncs; what the app does when it comes
    /// forward.
    func appBecameActive() async {
        autoStop.applyNow()
        await sync(.appBecameActive)
    }

    /// "Upload" on the sync screen: sends every finished session that is
    /// still waiting. Nothing else uploads (ADR 0015).
    func uploadNow() async {
        await sync(.upload)
    }

    func backgroundRefresh() async {
        await sync(.backgroundRefresh)
    }

    private func sync(_ trigger: SyncEngine.Trigger) async {
        isSyncing = true
        defer { isSyncing = false }
        lastOutcome = await engine.requestSync(trigger)
    }
}

#if DEBUG
extension SyncCoordinator {
    /// A coordinator over an in-memory container and the fake API, so a preview
    /// of the sync screen shows real state without touching the network.
    @MainActor
    static func preview(container: ModelContainer, connected: Bool = true) -> SyncCoordinator {
        let store = SessionStore(context: container.mainContext)
        return SyncCoordinator(
            engine: SyncEngine(
                container: container,
                apiProvider: { FakeZweefAPI() },
                // The same wiring the app uses: the engine supplies the club's
                // reporting language, not the UI's wording (ADR 0010).
                flagLabel: { flag, language in language.label(for: flag) }
            ),
            connectivity: StaticConnectivity(isCurrentlyConnected: connected),
            autoStop: AutoStopService(store: store) { try? store.settings() }
        )
    }
}
#endif

/// Stops timers that ran past the closing time, whenever the app gets a chance.
///
/// Separate from the sync engine because it has to work with no network at all:
/// a club with no coverage still needs its forgotten timers stopped at nine in
/// the evening rather than at nine the next morning.
@MainActor
final class AutoStopService {
    private let store: SessionStore
    private let settings: () -> AppSettings?

    init(store: SessionStore, settings: @escaping () -> AppSettings?) {
        self.store = store
        self.settings = settings
    }

    /// Applies the closing time now, and says how many timers it stopped.
    @discardableResult
    func applyNow() -> Int {
        let closing = settings()?.closingComponents ?? DateComponents(hour: 21, minute: 0)
        return (try? store.applyAutoStop(closing: closing)) ?? 0
    }

    /// Keeps applying it while the app is in the foreground.
    ///
    /// Every minute, which is as precise as the closing time needs to be, and
    /// cheap enough for a device that is plugged in all day.
    func runWhileActive() async {
        while !Task.isCancelled {
            applyNow()
            try? await Task.sleep(for: .seconds(60))
        }
    }
}
