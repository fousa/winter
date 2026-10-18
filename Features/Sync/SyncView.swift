import SwiftData
import SwiftUI

/// What is still on this device and what already reached zweef.app.
///
/// The point of this screen is that hours sitting on a device for days are
/// *visible* (ADR 0001): a member who closed the day in a hangar without
/// signal can check that nothing was lost.
///
/// It reads the stored sync state and asks ``SyncCoordinator`` to try again.
/// What it cannot yet show is a configured connection: until the setup
/// assistant exists (phase 4b) the app runs against a stub, so nothing actually
/// leaves the device and the counters only ever grow.
struct SyncView: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.locale) private var locale
    @Environment(SyncCoordinator.self) private var sync

    @Query private var sessions: [WorkSession]
    @Query private var members: [Member]
    @Query private var settings: [AppSettings]

    var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: metrics.sectionSpacing) {
                    VStack(spacing: metrics.sectionSpacing) { statusColumn }
                        .frame(maxWidth: 380)
                    VStack(spacing: metrics.sectionSpacing) { listColumn }
                }
                VStack(spacing: metrics.sectionSpacing) {
                    statusColumn
                    listColumn
                }
            }
            .padding(metrics.gutter)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Sync")
        .resolvedLayoutMetrics()
    }

    // MARK: - Status

    @ViewBuilder
    private var statusColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: statusSymbol)
                    .font(.largeTitle)
                    .foregroundStyle(sync.isConnected ? (waiting.isEmpty ? Color.runningTimer : .flag) : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    statusTitle
                        .font(.headline)
                    statusDetail
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                StatCard(
                    title: String(localized: "Sessions waiting"),
                    value: waiting.count.formatted()
                )
                StatCard(
                    title: String(localized: "Hours waiting"),
                    value: HoursFormatter.durationText(minutes: waitingMinutes, locale: locale)
                )
            }

            Button {
                Task { await sync.retryNow() }
            } label: {
                if sync.isSyncing {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: LayoutMetrics.minimumTapTarget)
                } else {
                    Label("Try again now", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: LayoutMetrics.minimumTapTarget)
                }
            }
            .buttonStyle(.glass)
            .disabled(sync.isSyncing)

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent(String(localized: "Last upload")) {
                    Text(relative(settings.first?.lastSuccessfulUploadAt))
                }
                LabeledContent(String(localized: "Last attempt")) {
                    Text(relative(settings.first?.lastAttemptAt))
                }
                LabeledContent(String(localized: "Members refreshed")) {
                    Text(relative(settings.first?.lastRefreshAt))
                }
                LabeledContent(String(localized: "Club")) {
                    Text(settings.first?.clubName ?? String(localized: "Not connected yet"))
                }
                LabeledContent(String(localized: "Maintenance period")) {
                    Text(settings.first?.activePeriodId.map(String.init) ?? String(localized: "Unknown"))
                }
            }
            .font(.subheadline)
        }
        .padding(metrics.gutter * 0.7)
        .background(.background, in: .rect(cornerRadius: metrics.cardCornerRadius))
    }

    // MARK: - Lists

    @ViewBuilder
    private var listColumn: some View {
        if !rejected.isEmpty {
            group(title: Text("Needs attention"), sessions: rejected, showsReason: true)
        }
        if !waiting.isEmpty {
            group(title: Text("Waiting to upload"), sessions: waiting, showsReason: false)
        }
        if !uploaded.isEmpty {
            group(title: Text("Recently uploaded"), sessions: uploaded, showsReason: false)
        }
        if rejected.isEmpty, waiting.isEmpty, uploaded.isEmpty {
            ContentUnavailableView(
                String(localized: "No hours yet"),
                systemImage: "clock",
                description: Text("Hours appear here once someone has worked and the day is closed.")
            )
        }
    }

    private func group(title: Text, sessions: [WorkSession], showsReason: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            title
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(name(for: session))
                                .font(.subheadline.weight(.medium))
                            Text(session.start.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if showsReason, let reason = session.lastError {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(.flag)
                            }
                        }
                        Spacer(minLength: 0)
                        if let minutes = session.minutes {
                            Text(HoursFormatter.durationText(minutes: minutes, locale: locale))
                                .font(.subheadline)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if session.id != sessions.last?.id { Divider() }
                }
            }
            .background(.background, in: .rect(cornerRadius: metrics.cardCornerRadius))
        }
    }

    // MARK: - Status

    private var statusSymbol: String {
        guard sync.isConnected else { return "wifi.slash" }
        return waiting.isEmpty ? "checkmark.icloud" : "icloud.and.arrow.up"
    }

    private var statusTitle: Text {
        if !sync.isConnected { return Text("No connection") }
        return waiting.isEmpty ? Text("Everything uploaded") : Text("Waiting to upload")
    }

    /// Honest about the one thing that is not wired up yet.
    private var statusDetail: Text {
        if let error = sync.lastOutcome?.error {
            switch error {
            case .notAuthorised:
                return Text("Connection refused: check the token in Settings")
            case .rejected:
                return Text("zweef.app refused one of the registrations")
            default:
                return Text("The hours stay on this device until the connection returns.")
            }
        }
        if !sync.isConnected {
            return Text("The hours stay on this device until the connection returns.")
        }
        return Text("This device has no zweef.app connection configured yet.")
    }

    // MARK: - Derived state

    private var waiting: [WorkSession] {
        sessions
            .filter { $0.status == .completed && ($0.syncState == .local || $0.syncState == .ready) }
            .sorted { $0.start > $1.start }
    }

    private var rejected: [WorkSession] {
        sessions.filter { $0.syncState == .rejected }.sorted { $0.start > $1.start }
    }

    private var uploaded: [WorkSession] {
        sessions.filter { $0.syncState == .uploaded }.sorted { $0.start > $1.start }
    }

    private var waitingMinutes: Minutes {
        waiting.compactMap(\.minutes).reduce(0, +)
    }

    private func name(for session: WorkSession) -> String {
        members.first { $0.zweefId == session.memberId }?.fullName
            ?? String(localized: "Unknown member")
    }

    private func relative(_ date: Date?) -> String {
        guard let date else { return String(localized: "Never") }
        return date.formatted(.relative(presentation: .named))
    }
}

#Preview("iPad · waiting", traits: .landscapeLeft) {
    let container = try! SampleData.closedDayContainer()
    NavigationStack { SyncView() }
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container))
}

#Preview("iPhone · no connection") {
    let container = try! SampleData.closedDayContainer()
    NavigationStack { SyncView() }
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container, connected: false))
}

#Preview("iPhone · nothing yet") {
    let container = try! SampleData.container()
    NavigationStack { SyncView() }
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container))
}
