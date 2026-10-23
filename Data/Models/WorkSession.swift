import Foundation
import SwiftData

/// Whether a session is still being worked on.
enum SessionStatus: String, Codable, Sendable {
    case running
    case completed
}

/// How far a finished session has got on its way to zweef.app.
///
/// The states are deliberately linear and stored, not derived: after a crash or
/// a flat battery the app has to know exactly what it had already uploaded.
enum SyncState: String, Codable, Sendable {
    /// Finished, and never tried: waiting for someone to upload it.
    case local
    /// An upload was tried and did not get through; waiting for the next
    /// tap on "Upload". (Before ADR 0018 this also meant "the day was
    /// closed", which is why stored sessions may have it without a try.)
    case ready
    /// A POST is in flight.
    case uploading
    /// Accepted by zweef.app.
    case uploaded
    /// Refused by zweef.app with a reason; needs a human, not a retry.
    case rejected
}

/// One period of work between a start and a stop: the thing the whole app
/// exists to record.
///
/// Written to disk the moment it is created and after every change, because an
/// hour that a member has logged must survive anything the device does next
/// (ADR 0001).
@Model
final class WorkSession {
    #Unique<WorkSession>([\.id])

    private(set) var id: UUID
    /// `Member.zweefId` rather than a relationship: a session must keep
    /// pointing at the right person even if the member list is refreshed,
    /// re-created, or the member is deactivated.
    var memberId: Int
    var start: Date
    var stop: Date?
    var status: SessionStatus
    /// `Material.zweefId` of what the work was on, or nil when nobody picked
    /// one — which is allowed (ADR 0020). Stored under its old name, from when
    /// only aircraft could be picked.
    @Attribute(originalName: "aircraftId") var materialId: Int?
    var autoStopped: Bool
    var stoppedByOther: Bool
    /// What the member typed when stopping; goes into the registration's
    /// description after the times (ADR 0019). Nil when they typed nothing.
    var comment: String?
    var syncState: SyncState
    /// The id zweef.app gave the registration, once it has one.
    var remoteId: Int?
    var lastError: String?
    var attempts: Int
    /// When this session was last pushed at zweef.app, successfully or not.
    ///
    /// Backoff is per session rather than per device: one registration that
    /// zweef.app keeps refusing must not hold back an hour that has never been
    /// tried.
    var lastAttemptAt: Date?
    var uploadedAt: Date?

    init(
        id: UUID = UUID(),
        memberId: Int,
        start: Date,
        stop: Date? = nil,
        status: SessionStatus = .running,
        materialId: Int? = nil,
        autoStopped: Bool = false,
        stoppedByOther: Bool = false,
        comment: String? = nil,
        syncState: SyncState = .local,
        remoteId: Int? = nil,
        lastError: String? = nil,
        attempts: Int = 0,
        lastAttemptAt: Date? = nil,
        uploadedAt: Date? = nil
    ) {
        self.id = id
        self.memberId = memberId
        self.start = start
        self.stop = stop
        self.status = status
        self.materialId = materialId
        self.autoStopped = autoStopped
        self.stoppedByOther = stoppedByOther
        self.comment = comment
        self.syncState = syncState
        self.remoteId = remoteId
        self.lastError = lastError
        self.attempts = attempts
        self.lastAttemptAt = lastAttemptAt
        self.uploadedAt = uploadedAt
    }

    /// The session as plain values, for the domain rules.
    var facts: SessionFacts {
        SessionFacts(
            start: start,
            stop: stop,
            autoStopped: autoStopped,
            stoppedByOther: stoppedByOther
        )
    }

    var flags: [SessionFlag] {
        SessionRules.flags(for: facts)
    }

    /// The duration in minutes, or nil while the session is running.
    var minutes: Minutes? {
        SessionRules.duration(of: facts)
    }
}
