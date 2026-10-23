import Foundation
import OSLog
import SwiftData

/// Moves finished hours to zweef.app, and brings members and aircraft back.
///
/// Everything here is best-effort and interruptible: the app has already done
/// its job by the time a session is stored (ADR 0001), so a failed run is not
/// an error a member needs to see — it is a state the sync screen reports.
///
/// Only a person uploads (ADR 0015). The automatic triggers stop forgotten
/// timers and refresh the members; hours leave the device when someone taps
/// "Upload" on the sync screen, so the club decides when they reach zweef.app.
///
/// An `actor` with its own `ModelContext` per run, so a long upload never
/// blocks the UI and never shares a context with it. Model objects are loaded
/// by id inside the run and never handed across the boundary.
actor SyncEngine {
    /// Why a run started: for the log, and for whether it uploads.
    enum Trigger: String, Sendable {
        case appBecameActive
        /// Setup just finished, or someone asked for the member list: fetch
        /// the members now rather than at the next activation.
        case membersRequested
        case connectivityReturned
        /// "Upload" on the sync screen: the only trigger that sends hours.
        case upload
        case backgroundRefresh
    }

    /// What a run did, for the screen that asked for it.
    struct Outcome: Equatable, Sendable {
        var uploaded = 0
        var rejected = 0
        var failed = 0
        var autoStopped = 0
        var refreshed = false
        /// The first error that stopped the run, if one did.
        var error: ZweefError?

        static let nothingToDo = Outcome()
    }

    private let container: ModelContainer
    /// Resolved at the start of every run, not captured at init: the setup
    /// assistant creates the connection after launch, and the settings screen
    /// can replace a token the club has revoked.
    private let apiProvider: @Sendable () -> any ZweefAPI
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "winter", category: "sync")

    /// Guards against two runs at once. Actors are reentrant, so a flag is
    /// needed as well as isolation: every `await` in a run is a chance for
    /// another trigger to arrive.
    private var isRunning = false
    /// At most one follow-up, no matter how many triggers arrive during a run.
    private var queuedTrigger: Trigger?

    init(
        container: ModelContainer,
        apiProvider: @escaping @Sendable () -> any ZweefAPI,
        calendar: Calendar = .club,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.container = container
        self.apiProvider = apiProvider
        self.calendar = calendar
        self.now = now
    }

    // MARK: - Running

    /// Asks for a sync, and waits for the run that answers it.
    ///
    /// Triggers that arrive while a run is in progress are merged into one
    /// follow-up rather than queued individually: five taps on "try again"
    /// should not mean five round trips.
    @discardableResult
    func requestSync(_ trigger: Trigger) async -> Outcome {
        if isRunning {
            // An upload outranks an automatic run, so pressing the button is
            // never swallowed by a background refresh's follow-up.
            if queuedTrigger == nil || trigger == .upload { queuedTrigger = trigger }
            return .nothingToDo
        }

        isRunning = true
        defer { isRunning = false }

        var outcome = await run(trigger)

        while let next = queuedTrigger {
            queuedTrigger = nil
            let followUp = await run(next)
            outcome = outcome.merging(followUp)
        }

        return outcome
    }

    private func run(_ trigger: Trigger) async -> Outcome {
        // One context per run: created here, on the actor's own executor, and
        // gone when the run ends. Nothing stale survives between runs.
        let context = ModelContext(container)
        let api = apiProvider()
        var outcome = Outcome()

        logger.info("Sync run started (\(trigger.rawValue, privacy: .public))")

        do {
            outcome.autoStopped = try applyAutoStop(in: context)
        } catch {
            logger.error("Auto-stop failed: \(String(describing: error), privacy: .public)")
        }

        do {
            outcome.refreshed = try await refreshIfDue(in: context, api: api)
        } catch ZweefError.invalidConfiguration {
            // Nothing is set up yet. Not worth a log line on every run: the
            // sync screen already says so, in words a member understands.
            outcome.error = .invalidConfiguration
        } catch let error as ZweefError {
            outcome.error = error
            log(.error, "Refresh failed", in: context)
            // A refresh failing is no reason not to upload: the hours matter
            // more than the member list being current.
        } catch {
            outcome.error = .unreachable
        }

        guard trigger == .upload else {
            logger.info("Sync run finished without uploading (\(trigger.rawValue, privacy: .public))")
            return outcome
        }

        // "Last attempt" on the sync screen means the last upload someone
        // asked for, not the last time the members were checked.
        if let settings = try? settings(in: context) {
            settings.lastAttemptAt = now()
            try? context.save()
        }

        do {
            let upload = try await uploadWaitingSessions(in: context, api: api)
            outcome.uploaded = upload.uploaded
            outcome.rejected = upload.rejected
            outcome.failed = upload.failed
            if outcome.error == nil { outcome.error = upload.error }
        } catch let error as ZweefError {
            outcome.error = outcome.error ?? error
        } catch {
            outcome.error = outcome.error ?? .unreachable
        }

        logger.info("""
            Sync run finished: \(outcome.uploaded, privacy: .public) uploaded, \
            \(outcome.rejected, privacy: .public) rejected, \
            \(outcome.failed, privacy: .public) failed
            """)

        return outcome
    }

    // MARK: - Auto-stop

    /// Stops timers that ran past the closing time, before anything is
    /// uploaded.
    ///
    /// First in the run on purpose: a forgotten timer stopped at the closing
    /// time is uploaded in the same pass as the rest.
    private func applyAutoStop(in context: ModelContext) throws -> Int {
        let settings = try settings(in: context)
        let closing = settings.closingComponents
        let moment = now()
        var stopped = 0

        for session in try context.fetch(FetchDescriptor<WorkSession>()) where session.status == .running {
            guard ClosingTime.shouldAutoStop(
                start: session.start,
                now: moment,
                closing: closing,
                calendar: calendar
            ) else { continue }

            session.stop = ClosingTime.autoStopDate(for: session.start, closing: closing, calendar: calendar)
            session.status = .completed
            session.syncState = .local
            session.autoStopped = true
            stopped += 1
        }

        if stopped > 0 {
            try context.save()
            log(.upload, "Stopped \(stopped) forgotten timer(s) at the closing time", in: context)
        }
        return stopped
    }

    // MARK: - Refresh

    /// Brings the club name, the members, the material and the active period
    /// up to date, at most once every six hours.
    private func refreshIfDue(in context: ModelContext, api: any ZweefAPI) async throws -> Bool {
        let settings = try settings(in: context)
        let memberCount = try context.fetchCount(FetchDescriptor<Member>())
        // No material yet — a fresh device, or one updated from the build that
        // kept only aircraft — means an empty "what did you work on?", so it
        // is fetched now rather than up to six hours later.
        let materialCount = try context.fetchCount(FetchDescriptor<Material>())

        guard RefreshPolicy.shouldRefresh(
            lastRefresh: settings.lastRefreshAt,
            now: now(),
            cacheIsEmpty: memberCount == 0 || materialCount == 0
        ) else { return false }

        // The club name is a nice-to-have: club.json answers 500 for a real
        // club, so a failure here must not abort the refresh (ADR 0012).
        if let club = try? await api.club() {
            settings.applyFetchedClubName(club.name, at: now())
        }

        let active = try await api.accounts(inactiveOnly: false)
        // A second call, because ?inactive=1 returns *only* inactive members.
        // They are kept so that an old session still shows a name.
        let inactive = (try? await api.accounts(inactiveOnly: true)) ?? []
        try upsert(accounts: active + inactive, in: context)

        let material = try await api.material()
        try upsert(material: material, in: context)

        if let periodId = try? await api.activePeriodId() {
            settings.activePeriodId = periodId
        }

        settings.lastRefreshAt = now()
        try context.save()
        log(.refresh, "Refreshed \(active.count) member(s) and \(material.count) item(s) of material", in: context)
        return true
    }

    /// Upserts members on `zweefId`, so a refresh never duplicates anybody.
    private func upsert(accounts: [ZweefAccount], in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Member>())
            .reduce(into: [Int: Member]()) { $0[$1.zweefId] = $1 }

        for account in accounts {
            if let member = existing[account.id] {
                member.firstName = account.firstName
                member.lastName = account.lastName
                member.isActive = account.isActive
                member.updatedAt = now()
            } else {
                context.insert(Member(
                    zweefId: account.id,
                    firstName: account.firstName,
                    lastName: account.lastName,
                    isActive: account.isActive,
                    updatedAt: now()
                ))
            }
        }
    }

    /// Mirrors zweef.app's material list: every visible item, in the three
    /// tabs of its own maintenance form (ADR 0020).
    ///
    /// Items zweef.app no longer lists, or hides, are removed, so the picker
    /// never offers something the board cannot book on. A session that
    /// already points at one keeps its `materialId`; only the name for
    /// `project` is then missing.
    private func upsert(material: [ZweefMaterial], in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Material>())
            .reduce(into: [Int: Material]()) { $0[$1.zweefId] = $1 }
        let listed = material.filter(\.isVisible)

        for item in listed {
            if let stored = existing[item.id] {
                stored.name = item.name
                stored.kindRaw = item.kind.rawValue
                stored.typeName = item.type ?? ""
                stored.isClubOwned = item.isClubOwned
                stored.isGlider = item.isGlider
                stored.sortOrder = item.order ?? 0
            } else {
                context.insert(Material(
                    zweefId: item.id,
                    name: item.name,
                    kind: item.kind,
                    typeName: item.type ?? "",
                    isClubOwned: item.isClubOwned,
                    isGlider: item.isGlider,
                    sortOrder: item.order ?? 0
                ))
            }
        }

        let listedIds = Set(listed.map(\.id))
        for (id, stored) in existing where !listedIds.contains(id) {
            context.delete(stored)
        }
    }

    // MARK: - Upload

    private struct UploadResult {
        var uploaded = 0
        var rejected = 0
        var failed = 0
        var error: ZweefError?
    }

    /// Uploads every finished session that has not reached zweef.app yet.
    ///
    /// The person who tapped "Upload" asked for the hours to go; running
    /// timers are simply not finished yet, so they stay. Sessions that an
    /// older version marked ready by closing the day count as waiting too
    /// (ADR 0018).
    private func uploadWaitingSessions(
        in context: ModelContext,
        api: any ZweefAPI
    ) async throws -> UploadResult {
        let settings = try settings(in: context)
        var result = UploadResult()

        guard let periodId = settings.activePeriodId else {
            // No period means nothing can be uploaded against it. The sessions
            // stay exactly where they are, which is the whole point of
            // offline-first; the sync screen shows them waiting.
            log(.error, "No active maintenance period yet; keeping sessions local", in: context)
            return result
        }

        let candidates = try uploadable(in: context)
        guard !candidates.isEmpty else { return result }

        // Fetched once per run, and only when something has failed before:
        // a session that was never tried cannot already be on the server.
        var alreadyUploaded: [ZweefMaintenanceHour]?
        if candidates.contains(where: { $0.attempts > 0 }) {
            alreadyUploaded = try? await api.currentPeriodHours()
        }

        for session in candidates {
            guard let draft = draft(for: session, periodId: periodId, in: context) else {
                session.lastError = "Could not be prepared for upload"
                session.syncState = .rejected
                result.rejected += 1
                continue
            }

            // An upload that timed out may well have arrived. Checking before
            // re-posting is the only thing standing between a dropped
            // connection and the same hours counted twice.
            if session.attempts > 0,
               let match = alreadyUploaded?.first(where: draft.isSameRegistration(as:)) {
                markUploaded(session, remoteId: match.id)
                result.uploaded += 1
                log(.upload, "Recognised a registration that had already arrived", in: context)
                continue
            }

            session.syncState = .uploading
            session.lastAttemptAt = now()
            try? context.save()

            do {
                let created = try await api.create(draft)
                markUploaded(session, remoteId: created.id)
                result.uploaded += 1
            } catch let error as ZweefError {
                switch error {
                case .rejected(let status, let reason):
                    session.syncState = .rejected
                    session.lastError = reason ?? "zweef.app refused this registration (\(status))"
                    session.attempts += 1
                    result.rejected += 1

                case .notAuthorised:
                    // Nothing else will get through either, so stop the run
                    // rather than burning through every session.
                    session.syncState = .ready
                    session.attempts += 1
                    session.lastError = "Connection refused: check the API key in Settings"
                    result.failed += 1
                    result.error = error
                    try? context.save()
                    log(.error, "Upload refused: the API key is not accepted", in: context)
                    return result

                default:
                    session.syncState = .ready
                    session.attempts += 1
                    session.lastError = nil
                    result.failed += 1
                    result.error = result.error ?? error
                }
            } catch {
                session.syncState = .ready
                session.attempts += 1
                result.failed += 1
                result.error = result.error ?? .unreachable
            }

            try? context.save()
        }

        if result.uploaded > 0 {
            settings.lastSuccessfulUploadAt = now()
            log(.upload, "Uploaded \(result.uploaded) session(s)", in: context)
        }
        try? context.save()

        return result
    }

    /// The finished sessions still waiting to upload, oldest first.
    ///
    /// No backoff: an upload only ever runs because someone asked for it, and
    /// they want an answer now. Rejected sessions stay out — zweef.app said no,
    /// and sending them again would get the same answer.
    private func uploadable(in context: ModelContext) throws -> [WorkSession] {
        try context.fetch(FetchDescriptor<WorkSession>(sortBy: [SortDescriptor(\.start)]))
            .filter { session in
                session.status == .completed
                    && (session.syncState == .ready || session.syncState == .local)
            }
    }

    private func draft(
        for session: WorkSession,
        periodId: Int,
        in context: ModelContext
    ) -> MaintenanceHourDraft? {
        let memberId = session.memberId
        let member = try? context.fetch(
            FetchDescriptor<Member>(predicate: #Predicate { $0.zweefId == memberId })
        ).first

        let materialId = session.materialId
        let material = materialId.flatMap { id in
            try? context.fetch(
                FetchDescriptor<Material>(predicate: #Predicate { $0.zweefId == id })
            ).first
        }

        return MaintenanceHourDraft(
            session: session,
            memberId: session.memberId,
            memberName: member?.fullName ?? "",
            project: material?.name,
            materialId: materialId,
            periodId: periodId,
            calendar: calendar
        )
    }

    private func markUploaded(_ session: WorkSession, remoteId: Int?) {
        session.syncState = .uploaded
        session.remoteId = remoteId
        session.uploadedAt = now()
        session.lastError = nil
    }

    // MARK: - Helpers

    private func settings(in context: ModelContext) throws -> AppSettings {
        if let existing = try context.fetch(FetchDescriptor<AppSettings>()).first { return existing }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }

    /// Adds a line to the sync log, which the sync screen shows.
    ///
    /// Never a member's name or a token: this is readable by anyone who picks
    /// up the device.
    private func log(_ kind: SyncLog.Kind, _ message: String, in context: ModelContext) {
        context.insert(SyncLog(at: now(), kind: kind, message: message))
        try? context.save()
    }
}

extension SyncEngine.Outcome {
    /// Adds a follow-up run's numbers to this one, so a caller that triggered
    /// once sees everything that happened because of it.
    func merging(_ other: Self) -> Self {
        SyncEngine.Outcome(
            uploaded: uploaded + other.uploaded,
            rejected: rejected + other.rejected,
            failed: failed + other.failed,
            autoStopped: autoStopped + other.autoStopped,
            refreshed: refreshed || other.refreshed,
            error: error ?? other.error
        )
    }
}
