import Foundation
import SwiftData

/// The only place that creates or changes a ``WorkSession``.
///
/// Having one door in front of the sessions is what makes the guarantees
/// testable: every mutation saves immediately (ADR 0001), and a member can
/// only have one running session. Views and view models call this; nothing
/// else writes sessions.
///
/// `@MainActor` because the mutations are small and immediate, and because the
/// UI reads the same context. The sync engine gets its own background context
/// instead of sharing this one.
@MainActor
final class SessionStore {
    /// What can go wrong, as cases rather than messages: the UI decides the
    /// wording, in three languages.
    enum StoreError: Error, Equatable {
        /// The member already has a running session. Carries it so the UI can
        /// offer to stop it instead.
        case memberAlreadyWorking(sessionId: UUID)
        case sessionNotRunning
        case sessionNotCompleted
    }

    private let context: ModelContext
    private let calendar: Calendar
    private let now: () -> Date

    /// - Parameters:
    ///   - now: Injected so the closing time, the undo window and "today" are
    ///     testable without waiting for a real clock.
    init(
        context: ModelContext,
        calendar: Calendar = .club,
        now: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.calendar = calendar
        self.now = now
    }

    // MARK: - Reading

    /// Every session that is still running, oldest first.
    func runningSessions() throws -> [WorkSession] {
        try allSessions()
            .filter { $0.status == .running }
            .sorted { $0.start < $1.start }
    }

    /// The running session of one member, if any.
    func runningSession(forMemberId memberId: Int) throws -> WorkSession? {
        try runningSessions().first { $0.memberId == memberId }
    }

    /// Sessions that started on the same day as `date`, oldest first.
    func sessions(onDayOf date: Date) throws -> [WorkSession] {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let descriptor = FetchDescriptor<WorkSession>(
            predicate: #Predicate { $0.start >= dayStart && $0.start < dayEnd },
            sortBy: [SortDescriptor(\.start)]
        )
        return try context.fetch(descriptor)
    }

    /// The club's settings, created with sensible defaults on first use.
    ///
    /// Fetch-or-create rather than a migration step, so a fresh install and an
    /// upgrade behave the same.
    func settings() throws -> AppSettings {
        if let existing = try context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }

    // MARK: - Starting and stopping

    /// Starts a session for `member`, saved before this method returns.
    ///
    /// - Throws: ``StoreError/memberAlreadyWorking(sessionId:)`` if the member
    ///   is already working, so the UI can send them to the stop sheet instead
    ///   of creating a second timer.
    @discardableResult
    func start(member: Member) throws -> WorkSession {
        if let running = try runningSession(forMemberId: member.zweefId) {
            throw StoreError.memberAlreadyWorking(sessionId: running.id)
        }

        let session = WorkSession(memberId: member.zweefId, start: now())
        context.insert(session)
        member.lastSeenAt = session.start
        try context.save()
        return session
    }

    /// Stops a running session and saves it, ready to upload.
    ///
    /// Stopping someone else's timer is allowed and is recorded rather than
    /// refused (ADR 0005).
    func stop(
        _ session: WorkSession,
        material: Material? = nil,
        comment: String? = nil,
        by stoppedBy: StoppedBy = .member
    ) throws {
        guard session.status == .running else { throw StoreError.sessionNotRunning }

        session.stop = now()
        session.status = .completed
        session.syncState = .local
        session.materialId = material?.zweefId
        let trimmed = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        session.comment = trimmed?.isEmpty == false ? trimmed : nil
        session.stoppedByOther = stoppedBy == .someoneElse
        try context.save()
    }

    /// Removes a running session from the device without finishing it.
    ///
    /// For the timer that was started by mistake, or for the wrong person, once
    /// the ten-second undo has passed. Nothing is kept and nothing reaches
    /// zweef.app: the hours were never real. Only a running session can be
    /// discarded — a finished one is on its way to the board, and corrections
    /// to those happen in zweef.app, not here.
    func discard(_ session: WorkSession) throws {
        guard session.status == .running else { throw StoreError.sessionNotRunning }
        context.delete(session)
        try context.save()
    }

    /// Undoes a start within the undo window: the session is removed entirely,
    /// because it never really happened.
    func undoStart(_ session: WorkSession) throws {
        try discard(session)
    }

    /// Undoes a stop: the session runs again, as if Stop had not been tapped.
    ///
    /// The material and comment are cleared too, because they were picked as part
    /// of stopping.
    func undoStop(_ session: WorkSession) throws {
        guard session.status == .completed else { throw StoreError.sessionNotCompleted }

        session.stop = nil
        session.status = .running
        session.syncState = .local
        session.materialId = nil
        session.comment = nil
        session.autoStopped = false
        session.stoppedByOther = false
        try context.save()
    }

    // MARK: - Closing time

    /// Stops every timer that has run past its closing time.
    ///
    /// The stop time is the closing time, not the moment this runs, so a timer
    /// noticed the next morning still reports the right hours.
    ///
    /// - Returns: How many sessions were stopped.
    @discardableResult
    func applyAutoStop(closing: DateComponents) throws -> Int {
        let moment = now()
        var stopped = 0

        for session in try runningSessions() {
            guard ClosingTime.shouldAutoStop(
                start: session.start,
                now: moment,
                closing: closing,
                calendar: calendar
            ) else { continue }

            session.stop = ClosingTime.autoStopDate(
                for: session.start,
                closing: closing,
                calendar: calendar
            )
            session.status = .completed
            session.syncState = .local
            session.autoStopped = true
            stopped += 1
        }

        if stopped > 0 { try context.save() }
        return stopped
    }

    // MARK: - Private

    /// Statuses are filtered in Swift rather than in a predicate.
    ///
    /// Sessions are kept for 90 days and a club logs a handful a day, so this
    /// is a few hundred rows at worst — not worth the fragility of putting
    /// stored enums into a `#Predicate`.
    private func allSessions() throws -> [WorkSession] {
        try context.fetch(FetchDescriptor<WorkSession>(sortBy: [SortDescriptor(\.start)]))
    }
}
