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

    /// What to present once the current sheet has finished closing.
    ///
    /// Swapping one sheet for another in a single step — Start for its
    /// confirmation, say — makes SwiftUI dismiss and present at the same time,
    /// and the two animations fight. So an action closes its sheet and queues
    /// the next screen here; the view presents it from the sheet's
    /// `onDismiss`, when the first animation is done.
    private(set) var queuedRoute: Route?

    /// The undo offer after a start, shown as a chip on the home screen.
    ///
    /// Starting has no confirmation card — the tile moving into "Working now"
    /// already says it worked — so this chip is the only way back from a
    /// start under the wrong name, for ten seconds (`docs/spec.md`).
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

        var id: String {
            switch self {
            case .start(let id): "start-\(id)"
            case .stop(let id): "stop-\(id)"
            case .confirmation(let confirmation): "confirmation-\(confirmation.sessionId)"
            }
        }
    }

    /// What the card after a stop says. Undoing it sets the session running
    /// again.
    struct Confirmation: Hashable {
        var sessionId: UUID
        var memberName: String
        /// The finished session's own summary: duration, task, aircraft.
        var summary: String
    }

    /// A start that can still be taken back.
    struct PendingUndo: Identifiable, Hashable {
        var sessionId: UUID
        var memberName: String
        var expiresAt: Date

        var id: UUID { sessionId }
    }

    /// How long undo stays available after a start, in seconds.
    static let undoWindow: TimeInterval = 10

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
    ///
    /// No confirmation card: the sheet closes, the tile moves into "Working
    /// now" with its clock running, and a haptic marks the moment. A card on
    /// top of that only stood between the member and the workshop.
    func start(member: Member, store: SessionStore) {
        do {
            let session = try store.start(member: member)
            feedback += 1
            pendingUndo = PendingUndo(
                sessionId: session.id,
                memberName: member.firstName,
                expiresAt: .now.addingTimeInterval(Self.undoWindow)
            )
            route = nil
        } catch SessionStore.StoreError.memberAlreadyWorking(let sessionId) {
            present(.stop(sessionId: sessionId))
        } catch {
            route = nil
        }
    }

    func stop(
        _ session: WorkSession,
        member: Member?,
        task: TaskDefinition?,
        aircraft: Aircraft?,
        store: SessionStore,
        locale: Locale = .current
    ) {
        do {
            try store.stop(session, task: task, aircraft: aircraft)
            feedback += 1
            // A start of this same session can no longer be undone.
            if pendingUndo?.sessionId == session.id { pendingUndo = nil }
            present(.confirmation(
                Confirmation(
                    sessionId: session.id,
                    memberName: member?.firstName ?? "",
                    summary: summary(for: session, task: task, aircraft: aircraft, locale: locale)
                )
            ))
        } catch {
            route = nil
        }
    }

    /// Throws a running timer away instead of saving it.
    ///
    /// The sheet has already asked "are you sure?", so there is no confirmation
    /// card and no undo here: the session is gone, and its tile leaves
    /// "Working now" at once. A pending undo for that same session is dropped,
    /// because there is nothing left to undo.
    func discard(_ session: WorkSession, store: SessionStore) {
        do {
            try store.discard(session)
            feedback += 1
            if pendingUndo?.sessionId == session.id { pendingUndo = nil }
        } catch {
            // The timer is still there, which the list behind the sheet shows.
        }
        route = nil
    }

    /// Takes a start back, inside the undo window: the session is deleted.
    func undoStart(_ undo: PendingUndo, sessions: [WorkSession], store: SessionStore) {
        if let session = sessions.first(where: { $0.id == undo.sessionId }) {
            do {
                try store.undoStart(session)
                feedback += 1
            } catch {
                // Nothing to tell the member: the session is simply still
                // there, which the list behind the chip already shows.
            }
        }
        pendingUndo = nil
    }

    /// Takes a stop back from its confirmation card: the session runs again.
    ///
    /// Possible for as long as the card is up — it stays until someone taps
    /// outside it — rather than for a fixed window, because the card is the
    /// only place the offer is shown.
    func undoStop(_ confirmation: Confirmation, sessions: [WorkSession], store: SessionStore) {
        if let session = sessions.first(where: { $0.id == confirmation.sessionId }) {
            do {
                try store.undoStop(session)
                feedback += 1
            } catch {
                // The session stays stopped, which the list shows.
            }
        }
        route = nil
    }

    /// Closes whatever is up and queues `next` for when it has gone.
    ///
    /// With nothing up there is nothing to wait for, so `next` is shown at once.
    func present(_ next: Route) {
        if route == nil {
            route = next
        } else {
            queuedRoute = next
            route = nil
        }
    }

    /// Called from the sheet's `onDismiss`: shows what an action queued, now
    /// that the previous sheet has finished animating away.
    func presentQueuedRoute() {
        guard let next = queuedRoute else { return }
        queuedRoute = nil
        route = next
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
