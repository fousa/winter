import Foundation
import Network

/// Reports whether a device has a usable connection.
///
/// A protocol so a preview can be offline on purpose and a test never depends
/// on the machine it runs on.
protocol ConnectivityReporting: Sendable {
    var isCurrentlyConnected: Bool { get }
    func changes() -> AsyncStream<Bool>
}

/// A fixed answer, for previews and tests.
struct StaticConnectivity: ConnectivityReporting {
    let isCurrentlyConnected: Bool

    func changes() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            continuation.yield(isCurrentlyConnected)
            continuation.finish()
        }
    }
}

/// Reports whether this device currently has a usable connection.
///
/// Used to *trigger* a sync, never to decide whether an action is allowed:
/// starting, stopping and closing the day work regardless (ADR 0001). The club
/// wifi drops often enough that polling would be wasteful, so this watches the
/// path and says something only when it changes.
final class ConnectivityMonitor: ConnectivityReporting, Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "winter.connectivity")

    /// Every change in reachability, starting with the current state.
    ///
    /// An `AsyncStream` rather than a callback so the app can simply
    /// `for await` it next to its other work, and so cancellation tears the
    /// monitor down with the task that owns it.
    func changes() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { [monitor] _ in
                monitor.cancel()
            }
            monitor.start(queue: queue)
        }
    }

    /// A one-off answer, for a screen that wants to show the state right now.
    var isCurrentlyConnected: Bool {
        monitor.currentPath.status == .satisfied
    }
}
