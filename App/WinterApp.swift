import BackgroundTasks
import SwiftUI

/// The app's entry point: picks the environment — the real app, or the sample
/// club while it is being tried — and wires the triggers that keep hours moving.
@main
struct WinterApp: App {
    /// Must match the `BGTaskSchedulerPermittedIdentifiers` entry in
    /// `App/Info.plist`, or the system refuses every request.
    ///
    /// `nonisolated` because the background task scheduling happens off the
    /// main actor.
    nonisolated static let refreshTaskIdentifier = "app.winter.refresh"

    /// The real app — or, in a Debug build launched with `-sampleClub`, the
    /// sample club in its place. Kept for the whole run, so leaving the demo
    /// returns to exactly this.
    @State private var live: AppEnvironment
    /// The sample club while someone is trying it (ADR 0021); nil otherwise.
    @State private var demo: AppEnvironment?

    @Environment(\.scenePhase) private var scenePhase

    init() {
        _live = State(initialValue: Self.debugSampleClub() ?? .live())
        #if DEBUG
        // `-demo`: open straight into the demo, as if "Try with a sample club"
        // had been tapped — for checking it on a simulator (CONTRIBUTING.md).
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            _demo = State(initialValue: .demo())
        }
        #endif
    }

    /// Whichever mode is showing.
    private var current: AppEnvironment { demo ?? live }

    var body: some Scene {
        WindowGroup {
            RootView(configuration: current.configuration, secrets: current.secrets, connection: current.connection)
                .environment(current.sync)
                .environment(\.startDemo, demo == nil ? DemoAction(.start) { demo = .demo() } : nil)
                .environment(\.leaveDemo, demo == nil ? nil : DemoAction(.leave) { demo = nil })
                .modelContainer(current.container)
                // A fresh view tree per mode: nothing from the demo's screens
                // survives into the real app, or the other way round.
                .id(ObjectIdentifier(current))
                .task(id: ObjectIdentifier(current)) { await current.sync.watchConnectivity() }
                .task(id: ObjectIdentifier(current)) { await current.autoStop.runWhileActive() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await current.sync.appBecameActive() }
            case .background:
                scheduleBackgroundRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(WinterApp.refreshTaskIdentifier)) {
            // Best effort: the system decides whether this ever runs. Hours are
            // safe on the device either way; this only shortens the wait. Always
            // the real app's: the demo has nothing worth refreshing.
            await live.sync.backgroundRefresh()
            scheduleBackgroundRefresh()
        }
    }

    /// Debug builds only: `-sampleClub 3` launches straight into the home
    /// screen of the sample club with three timers running, in memory and
    /// with a fake zweef.app, so a screen can be looked at on a simulator
    /// without a key. Nothing is written to disk and nothing is uploaded.
    ///
    /// With `-sampleScreen sync` or `-sampleScreen stop` the club also has
    /// finished sessions, and the home screen opens that screen on launch.
    private static func debugSampleClub() -> AppEnvironment? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-sampleClub") else { return nil }
        let running = arguments.indices.contains(index + 1) ? Int(arguments[index + 1]) ?? 0 : 0
        return .sampleClub(
            runningSessionCount: running,
            withFinishedSessions: arguments.contains("-sampleScreen"),
            isDemo: false
        )
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
