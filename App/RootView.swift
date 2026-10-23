import SwiftData
import SwiftUI

/// Decides what the app opens on: the setup assistant until the device can
/// actually reach zweef.app, otherwise the home screen.
///
/// Setup is not skippable, because a device that records hours it can never
/// deliver is worse than one that asks four questions first — nobody would find
/// out until the board asked where the hours went.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(SyncCoordinator.self) private var sync

    @Query private var tasks: [TaskDefinition]
    @Query private var storedSettings: [AppSettings]

    let configuration: AppConfiguration
    let secrets: any SecretStore
    let connection: ConnectionProvider

    /// Flipped when setup finishes, so the root re-reads the configuration.
    @State private var setupGeneration = 0
    @State private var isAskingAdminCode = false
    @State private var isShowingSettings = false

    var body: some View {
        Group {
            if configuration.isComplete(secrets: secrets) {
                HomeView()
                    .task { seedTasksIfNeeded() }
                    .onLongPressTitle { isAskingAdminCode = true }
            } else {
                SetupView(
                    model: SetupModel(
                        configuration: configuration,
                        secrets: secrets,
                        connection: connection,
                        settings: settings
                    )
                ) {
                    seedTasksIfNeeded()
                    setupGeneration += 1
                    // Nothing else would fetch the members until the app is
                    // next brought forward, so the home screen would open
                    // empty.
                    Task { await sync.refreshMembers() }
                }
            }
        }
        .id(setupGeneration)
        .sheet(isPresented: $isAskingAdminCode) {
            AdminCodeSheet(
                verifier: AdminCodeVerifier(secrets: secrets, configuration: configuration)
            ) {
                isAskingAdminCode = false
                isShowingSettings = true
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                configuration: configuration,
                secrets: secrets,
                connection: connection,
                settings: settings
            )
        }
    }

    /// The club's settings row, created on first launch.
    private var settings: AppSettings {
        if let existing = storedSettings.first { return existing }
        let created = AppSettings()
        context.insert(created)
        try? context.save()
        return created
    }

    /// The default task list is seeded in the language the app is running in,
    /// after which the labels are the club's own and are never translated
    /// (ADR 0010).
    private func seedTasksIfNeeded() {
        guard tasks.isEmpty else { return }
        for task in DefaultTasks.seed(locale: locale) {
            context.insert(task)
        }
        try? context.save()
    }
}

extension View {
    /// The hidden way into the settings: hold the title for three seconds.
    ///
    /// Hidden rather than absent so members never tap it by accident, and long
    /// rather than a tap sequence so it survives a toddler in the clubhouse.
    func onLongPressTitle(perform action: @escaping () -> Void) -> some View {
        simultaneousGesture(
            LongPressGesture(minimumDuration: 3).onEnded { _ in action() }
        )
    }
}

#Preview("Needs setup", traits: .landscapeLeft) {
    let container = try! WinterSchema.inMemoryContainer()
    RootView(
        configuration: AppConfiguration(defaults: UserDefaults(suiteName: "preview-root-empty") ?? .standard),
        secrets: InMemorySecretStore(),
        connection: ConnectionProvider()
    )
    .modelContainer(container)
    .environment(SyncCoordinator.preview(container: container))
}

#Preview("Configured", traits: .landscapeLeft) {
    let container = try! SampleData.container(runningSessionCount: 2)
    let defaults = UserDefaults(suiteName: "preview-root-ready") ?? .standard
    let configuration = AppConfiguration(defaults: defaults)
    configuration.clubSchema = "exampleclub"
    configuration.hasCompletedSetup = true

    return RootView(
        configuration: configuration,
        secrets: InMemorySecretStore([.apiKey: "key", .adminCode: "salt:hash"]),
        connection: ConnectionProvider()
    )
    .modelContainer(container)
    .environment(SyncCoordinator.preview(container: container))
}
