import SwiftData
import SwiftUI

/// Decides what the app opens on.
///
/// It will show the setup assistant while the configuration is incomplete and
/// the home screen afterwards; the assistant and the configuration it checks
/// arrive in phase 4b of `PLAN.md`. Until then it seeds the club's default task
/// list on first launch, so the stop sheet has something to offer, and opens
/// the home screen.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale

    @Query private var tasks: [TaskDefinition]

    var body: some View {
        HomeView()
            .task { seedTasksIfNeeded() }
    }

    /// The default list is seeded in the language the app is running in, after
    /// which the labels are the club's own and are never translated (ADR 0010).
    private func seedTasksIfNeeded() {
        guard tasks.isEmpty else { return }
        for task in DefaultTasks.seed(locale: locale) {
            context.insert(task)
        }
        try? context.save()
    }
}

#Preview("Nobody working", traits: .landscapeLeft) {
    let container = try! SampleData.container()
    RootView()
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container))
}

#Preview("A day's work", traits: .landscapeLeft) {
    let container = try! SampleData.closedDayContainer()
    RootView()
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container))
}
