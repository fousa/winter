import SwiftData
import SwiftUI

/// The app's entry point: builds the one model container and hands it to the
/// view tree.
///
/// Deciding between the setup assistant and the home screen happens in
/// ``RootView``, once there is a configuration to check.
@main
struct WinterApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try WinterSchema.container()
        } catch {
            // Nothing can be recorded without a store, and silently running on
            // an in-memory one would lose a member's hours without telling
            // anyone — which is the one thing this app must never do.
            fatalError("Could not open the Winter database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
