import Foundation

/// What can come back instead of data.
///
/// Split by what the app should *do*, not by status code: retry, stop and ask a
/// human, or give up on this one registration (`docs/architecture.md`).
enum ZweefError: Error, Equatable {
    /// The proxy URL or club schema is unusable. Needs the settings screen.
    case invalidConfiguration

    /// 401/403. The device token or API key is wrong or was revoked. Retrying
    /// will not help, and the sync screen says so.
    case notAuthorised

    /// Any other 4xx: zweef.app refuses this registration on its merits — an
    /// inactive member, a closed period. A human has to fix it, so the session
    /// is marked rejected rather than retried forever.
    case rejected(status: Int, reason: String?)

    /// 5xx. zweef.app's problem, so retry with backoff.
    case server(status: Int)

    /// No network, a timeout, a dropped connection. Entirely expected at a
    /// gliding club; retry later.
    case unreachable

    /// The response was not the shape we expected. Worth surfacing rather than
    /// swallowing: it means zweef.app changed and the mapping needs attention.
    case decoding(String)

    /// Whether waiting and trying again could plausibly work.
    var isRetryable: Bool {
        switch self {
        case .server, .unreachable: true
        case .invalidConfiguration, .notAuthorised, .rejected, .decoding: false
        }
    }
}
