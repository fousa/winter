import Foundation
import SwiftData

/// One line of sync history, for the sync screen.
///
/// Kept as data rather than only in `os.Logger` so that a member in a hangar
/// can see what the app has been trying, without anyone having to attach a Mac.
/// Never contains tokens, keys or personal data.
@Model
final class SyncLog {
    var at: Date
    var kind: String
    var message: String

    init(at: Date = .now, kind: Kind, message: String) {
        self.at = at
        self.kind = kind.rawValue
        self.message = message
    }

    enum Kind: String, Sendable {
        case upload
        case refresh
        case error
    }
}
