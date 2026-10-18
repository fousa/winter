import SwiftData
import SwiftUI

/// Temporary scaffold while the screens are being built.
///
/// It shows that the store is wired up and working. The real root — the setup
/// assistant while the configuration is incomplete, otherwise the home screen —
/// replaces this in phase 2 of `PLAN.md`, together with the copy in the string
/// catalog. Nothing here is localised, because none of it ships.
struct RootView: View {
    @Environment(\.modelContext) private var context

    @Query private var members: [Member]
    @Query(filter: #Predicate<WorkSession> { $0.stop == nil }) private var running: [WorkSession]

    var body: some View {
        NavigationStack {
            List {
                Section("Store") {
                    LabeledContent("Members", value: members.count.formatted())
                    LabeledContent("Running sessions", value: running.count.formatted())
                }
                Section("Next") {
                    Text("Screens are built in phase 2 of PLAN.md.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Winter")
        }
    }
}

#Preview("Nobody working") {
    RootView()
        .modelContainer(try! SampleData.container())
}

#Preview("Two working") {
    RootView()
        .modelContainer(try! SampleData.container(runningSessionCount: 2))
}
