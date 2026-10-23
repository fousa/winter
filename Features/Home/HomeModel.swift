import Foundation
import SwiftData
import SwiftUI

/// The home screen's own state and the actions it can take.
///
/// Reading is left to `@Query` in the view, because SwiftData already pushes
/// changes into the view when a session starts or stops and re-implementing
/// that here would only add a way to be out of date. What lives here is what
/// `@Query` cannot do: the state of the screen, and the writes — which all go
/// through ``SessionStore`` so the rules stay in one place.
///
/// It holds no store of its own. ``SessionStore`` is a thin façade over the
/// model context, so the view hands one to each action: that keeps this type
/// out of lifecycle order (there is no context yet when a `@State` model is
/// created) and makes it trivial to drive from a preview.
@MainActor
@Observable
final class HomeModel {
    /// What the member list is filtered by.
    var searchText = ""

    /// Which sheet is up, if any.
    var route: Route?

    /// The undo offer that outlives the confirmation card.
    ///
    /// The card closes after three seconds, but undo is promised for ten
    /// (`docs/spec.md`), so the remainder lives on as a chip on the home
    /// screen.
    var pendingUndo: PendingUndo?

    /// Bumped to fire haptics; `sensoryFeedback` watches it.
    var feedback = 0

    /// What is presented on top of the home screen.
    ///
    /// Only the modal routes: "close day" and "sync" are pushed screens and
    /// live in the navigation path instead, which is where SwiftUI wants
    /// navigation state to be.
    enum Route: Identifiable, Hashable {
        case start(memberId: Int)
        case stop(sessionId: UUID)
        case confirmation(Confirmation)
        /// Compact width only: which of the running timers did you mean?
        case runningList

        var id: String {
            switch self {
            case .start(let id): "start-\(id)"
            case .stop(let id): "stop-\(id)"
            case .confirmation(let confirmation): "confirmation-\(confirmation.sessionId)"
            case .runningList: "running-list"
            }
        }
    }

    /// What a confirmation card says, and what undoing it means.
    struct Confirmation: Hashable {
        enum Kind: Hashable {
            case started
            case stopped
        }

        var kind: Kind
        var sessionId: UUID
        var memberName: String
        /// Set for a stop: the finished session's own summary.
        var summary: String?
    }

    struct PendingUndo: Identifiable, Hashable {
        var sessionId: UUID
        var kind: Confirmation.Kind
        var memberName: String
        var expiresAt: Date

        var id: UUID { sessionId }
    }

    /// How long undo stays available after an action, in seconds.
    static let undoWindow: TimeInterval = 10

    /// How long the confirmation card stays up before closing itself.
    static let confirmationDuration: Duration = .seconds(3)

    // MARK: - Derived lists

    func sessionCounts(for sessions: [WorkSession], now: Date = .now) -> [Int: Int] {
        MemberDirectory.sessionCounts(
            starts: sessions.map { (memberId: $0.memberId, start: $0.start) },
            now: now
        )
    }

    // MARK: - Actions

    /// Starts a session, or sends the member to the stop sheet if they are
    /// already working — which is the one thing a member on a shared device is
    /// most likely to do by accident.
    func start(member: Member, store: SessionStore) {
        do {
            let session = try store.start(member: member)
            feedback += 1
            offerUndo(sessionId: session.id, kind: .started, memberName: member.firstName)
            route = .confirmation(
                Confirmation(kind: .started, sessionId: session.id, memberName: member.firstName)
            )
        } catch SessionStore.StoreError.memberAlreadyWorking(let sessionId) {
            route = .stop(sessionId: sessionId)
        } catch {
            route = nil
        }
    }

    func stop(
        _ session: WorkSession,
        member: Member?,
        task: TaskDefinition?,
        aircraft: Aircraft?,
        by stoppedBy: StoppedBy,
        store: SessionStore,
        locale: Locale = .current
    ) {
        do {
            try store.stop(session, task: task, aircraft: aircraft, by: stoppedBy)
            feedback += 1
            let name = member?.firstName ?? ""
            offerUndo(sessionId: session.id, kind: .stopped, memberName: name)
            route = .confirmation(
                Confirmation(
                    kind: .stopped,
                    sessionId: session.id,
                    memberName: name,
                    summary: summary(for: session, task: task, aircraft: aircraft, locale: locale)
                )
            )
        } catch {
            route = nil
        }
    }

    /// Throws a running timer away instead of saving it.
    ///
    /// The sheet has already asked "are you sure?", so there is no confirmation
    /// card and no undo here: the session is gone, and the "Working now" bar
    /// shows that at once. A pending undo for that same session is dropped,
    /// because there is nothing left to undo.
    func discard(_ session: WorkSession, store: SessionStore) {
        do {
            try store.discard(session)
            feedback += 1
            if pendingUndo?.sessionId == session.id { pendingUndo = nil }
        } catch {
            // The timer is still there, which the bar behind the sheet shows.
        }
        route = nil
    }

    /// Takes back whatever the last action was, inside the undo window.
    func undo(_ undo: PendingUndo, sessions: [WorkSession], store: SessionStore) {
        guard let session = sessions.first(where: { $0.id == undo.sessionId }) else {
            pendingUndo = nil
            return
        }

        do {
            switch undo.kind {
            case .started: try store.undoStart(session)
            case .stopped: try store.undoStop(session)
            }
            feedback += 1
        } catch {
            // Nothing to tell the member: the session is simply still there,
            // which the list behind the chip already shows.
        }
        pendingUndo = nil
        route = nil
    }

    /// Drops the undo offer once its ten seconds are up.
    func expireUndo(now: Date = .now) {
        if let pendingUndo, pendingUndo.expiresAt <= now {
            self.pendingUndo = nil
        }
    }

    func canCloseDay(runningCount: Int) -> Bool {
        SessionRules.canCloseDay(runningCount: runningCount)
    }

    private func offerUndo(sessionId: UUID, kind: Confirmation.Kind, memberName: String) {
        pendingUndo = PendingUndo(
            sessionId: sessionId,
            kind: kind,
            memberName: memberName,
            expiresAt: .now.addingTimeInterval(Self.undoWindow)
        )
    }

    private func summary(
        for session: WorkSession,
        task: TaskDefinition?,
        aircraft: Aircraft?,
        locale: Locale
    ) -> String {
        var parts: [String] = []
        if let minutes = session.minutes {
            parts.append(HoursFormatter.durationText(minutes: minutes, locale: locale))
        }
        if let task { parts.append(task.label) }
        if let aircraft { parts.append(aircraft.name) }
        return parts.joined(separator: " · ")
    }
}
