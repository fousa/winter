import Foundation

/// A number of whole minutes.
///
/// Hours are tracked in minutes rather than seconds because that is the
/// smallest unit anyone cares about in a workshop, and because zweef.app wants
/// decimal hours with two decimals in the end anyway.
typealias Minutes = Int

/// Something notable about a session that the board should see in zweef.app.
///
/// Flags are deliberately *not* errors or warnings: the app never refuses an
/// hour. They travel along in the registration's description so the board can
/// correct a time that was stopped automatically, or spot a session that is
/// suspiciously short, without the app having to guess what was meant.
enum SessionFlag: String, CaseIterable, Sendable {
    /// Shorter than ``SessionRules/shortSessionThreshold``. Probably a mis-tap.
    case shortSession
    /// Longer than ``SessionRules/longSessionThreshold``. Probably a forgotten timer.
    case longSession
    /// Stopped by the closing time instead of by a person.
    case stoppedAutomatically
    /// Stopped by a different member than the one doing the work.
    case stoppedBySomeoneElse
}

/// The plain-value view of a session that the domain rules work on.
///
/// The rules take this instead of a `WorkSession` so that `Domain` never has to
/// import SwiftData: that keeps every rule testable without a model container,
/// which is the whole reason the layer exists.
struct SessionFacts: Equatable, Sendable {
    var start: Date
    var stop: Date?
    var autoStopped: Bool
    var stoppedByOther: Bool

    init(start: Date, stop: Date? = nil, autoStopped: Bool = false, stoppedByOther: Bool = false) {
        self.start = start
        self.stop = stop
        self.autoStopped = autoStopped
        self.stoppedByOther = stoppedByOther
    }
}

/// Who stopped a session, which decides whether it gets
/// ``SessionFlag/stoppedBySomeoneElse``.
///
/// Stopping someone else's forgotten timer is allowed on purpose (ADR 0005), so
/// this is a label on the result, not a permission check.
enum StoppedBy: String, Sendable {
    case member
    case someoneElse
}
