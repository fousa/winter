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
    /// When the break the member is on began, or nil while they work.
    ///
    /// A paused timer is still a running session: `status` stays `.running`,
    /// so it keeps its tile, is never uploaded, and is found by the closing
    /// time like any other (ADR 0022). Optional, so a database from before
    /// pausing existed opens as it is.
    var pausedAt: Date?
    /// The finished breaks, as JSON; read and written through ``breaks``.
    ///
    /// Encoded by hand rather than stored as an array of structs: a plain
    /// optional `Data` is the one shape that is certain to migrate untouched
    /// and to read back the same on every OS version.
    private(set) var breaksData: Data?
    /// The session was stopped while paused — by a person or by the closing
    /// time — so `stop` is where that break began. Remembered so that undoing
    /// the stop puts the member back on their break.
    var endedOnBreak: Bool = false
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
        pausedAt: Date? = nil,
        breaks: [WorkBreak] = [],
        endedOnBreak: Bool = false,
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
        self.pausedAt = pausedAt
        self.breaksData = Self.encode(breaks)
        self.endedOnBreak = endedOnBreak
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

    /// The breaks that are over, oldest first.
    var breaks: [WorkBreak] {
        get {
            guard let breaksData else { return [] }
            // Unreadable data means no breaks rather than a crash: the worst
            // case is an hour too many, which the board can correct, not a
            // session that cannot be shown.
            return (try? JSONDecoder().decode([WorkBreak].self, from: breaksData)) ?? []
        }
        set { breaksData = Self.encode(newValue) }
    }

    /// Nil for no breaks, so the common case stores nothing at all.
    private static func encode(_ breaks: [WorkBreak]) -> Data? {
        breaks.isEmpty ? nil : try? JSONEncoder().encode(breaks)
    }

    /// Whether the member is on a break right now.
    var isPaused: Bool {
        status == .running && pausedAt != nil
    }

    /// The session as plain values, for the domain rules.
    var facts: SessionFacts {
        SessionFacts(
            start: start,
            stop: stop,
            autoStopped: autoStopped,
            stoppedByOther: stoppedByOther,
            breaks: breaks,
            pausedAt: pausedAt,
            endedOnBreak: endedOnBreak
        )
    }

    var flags: [SessionFlag] {
        SessionRules.flags(for: facts)
    }

    /// The time worked in minutes, breaks taken out, or nil while the session
    /// is running.
    var minutes: Minutes? {
        SessionRules.duration(of: facts)
    }

    /// How long the finished breaks took together.
    var breakMinutes: Minutes {
        SessionRules.breakMinutes(of: facts)
    }

    /// Ends a running session because the closing time has passed.
    ///
    /// Here rather than in ``SessionStore`` because the sync engine applies
    /// the closing time too, on its own context, and the two must agree on
    /// what it does. A timer that is paused ends where its break began:
    /// nobody was working after that, and a pause never outlives the day
    /// (ADR 0022).
    func end(atClosingTime closing: Date) {
        if let pausedAt {
            stop = min(pausedAt, closing)
            endedOnBreak = true
            self.pausedAt = nil
        } else {
            stop = closing
        }
        status = .completed
        syncState = .local
        autoStopped = true
    }
}
