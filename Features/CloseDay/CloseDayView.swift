import SwiftData
import SwiftUI

/// The day's hours, and the button that hands them to zweef.app.
///
/// Anyone can close the day, but only once nothing is running (ADR 0005), so
/// this screen is reachable with the button disabled and says why. Sessions
/// from earlier days that nobody closed are listed too, under "Also included",
/// because they go along with this closing.
struct CloseDayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.metrics) private var metrics
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncCoordinator.self) private var sync

    @Query private var sessions: [WorkSession]
    @Query private var members: [Member]
    @Query(sort: \TaskDefinition.sortOrder) private var tasks: [TaskDefinition]

    @State private var feedback = 0

    private var store: SessionStore { SessionStore(context: context) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                stats
                sessionList(title: Text("Today"), sessions: todaysSessions)
                if !earlierSessions.isEmpty {
                    sessionList(title: Text("Also included"), sessions: earlierSessions)
                }
            }
            .padding(metrics.gutter)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Close day")
        .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .safeAreaInset(edge: .bottom) { closeBar }
        .sensoryFeedback(.success, trigger: feedback)
        .resolvedLayoutMetrics()
    }

    // MARK: - Content

    private var stats: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { statCards }
            VStack(spacing: 10) { statCards }
        }
    }

    @ViewBuilder
    private var statCards: some View {
        StatCard(title: String(localized: "Sessions today"), value: todaysSessions.count.formatted())
        StatCard(
            title: String(localized: "Total"),
            value: HoursFormatter.durationText(minutes: totalMinutes, locale: locale)
        )
        StatCard(
            title: String(localized: "Also from earlier days"),
            value: earlierSessions.count.formatted()
        )
    }

    private func sessionList(title: Text, sessions: [WorkSession]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            title
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            if sessions.isEmpty {
                Text("Nothing logged yet.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        row(for: session)
                        if session.id != sessions.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(.background, in: .rect(cornerRadius: metrics.cardCornerRadius))
            }
        }
    }

    private func row(for session: WorkSession) -> some View {
        HStack(spacing: 12) {
            if let member = member(for: session) {
                MemberAvatar(member: member, size: 40)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(member(for: session)?.fullName ?? String(localized: "Unknown member"))
                    .font(.headline)

                Text(timeRange(for: session))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !session.flags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(session.flags, id: \.self) { FlagBadge(flag: $0) }
                    }
                }
            }

            Spacer(minLength: 0)

            if let minutes = session.minutes {
                Text(HoursFormatter.durationText(minutes: minutes, locale: locale))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var closeBar: some View {
        GlassBar {
            HStack(spacing: 12) {
                Image(systemName: runningCount > 0 ? "clock.badge.exclamationmark" : "icloud.and.arrow.up")
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    (runningCount > 0
                        ? Text("^[\(runningCount) timer](inflect: true) still running")
                        : Text("^[\(closableSessions.count) session](inflect: true) ready"))
                        .font(.subheadline.weight(.semibold))
                    (runningCount > 0
                        ? Text("Stop them first, then close the day.")
                        : Text("They go to zweef.app by themselves once this device has a connection."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button {
                    close()
                } label: {
                    Text("Close day")
                        .frame(minHeight: LayoutMetrics.minimumTapTarget)
                }
                .buttonStyle(.glassProminent)
                .disabled(runningCount > 0 || closableSessions.isEmpty)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Derived state

    private var runningCount: Int {
        sessions.filter { $0.status == .running }.count
    }

    private var todaysSessions: [WorkSession] {
        let startOfDay = Calendar.club.startOfDay(for: .now)
        return sessions
            .filter { $0.status == .completed && $0.start >= startOfDay }
            .sorted { $0.start < $1.start }
    }

    private var earlierSessions: [WorkSession] {
        let startOfDay = Calendar.club.startOfDay(for: .now)
        return sessions
            .filter { $0.status == .completed && $0.start < startOfDay && $0.syncState == .local }
            .sorted { $0.start < $1.start }
    }

    private var closableSessions: [WorkSession] {
        sessions.filter { $0.status == .completed && $0.syncState == .local }
    }

    private var totalMinutes: Minutes {
        todaysSessions.compactMap(\.minutes).reduce(0, +)
    }

    private func member(for session: WorkSession) -> Member? {
        members.first { $0.zweefId == session.memberId }
    }

    private func timeRange(for session: WorkSession) -> String {
        let start = session.start.formatted(date: .omitted, time: .shortened)
        guard let stop = session.stop?.formatted(date: .omitted, time: .shortened) else { return start }
        var text = "\(start) – \(stop)"
        if let task = tasks.first(where: { $0.key == session.taskKey }) {
            text += " · \(task.label)"
        }
        return text
    }

    private func close() {
        do {
            try store.closeDay()
            feedback += 1
            // Closing the day is a sync trigger (docs/sync.md): the hours go up
            // now if there is a connection, and wait if there is not.
            Task { await sync.dayWasClosed() }
            dismiss()
        } catch {
            // The only reason closing fails is a timer that started while this
            // screen was open; the bar above already shows that state.
        }
    }
}

#Preview("iPad", traits: .landscapeLeft) {
    let container = try! SampleData.closedDayContainer()
    NavigationStack {
        CloseDayView()
    }
    .modelContainer(container)
    .environment(SyncCoordinator.preview(container: container))
}

#Preview("iPhone · timers running") {
    let container = try! SampleData.container(runningSessionCount: 2)
    NavigationStack {
        CloseDayView()
    }
    .modelContainer(container)
    .environment(SyncCoordinator.preview(container: container))
}
