import SwiftData
import SwiftUI

/// What is still on this device and what already reached zweef.app.
///
/// The point of this screen is that hours sitting on a device for days are
/// *visible* (ADR 0001): a member who closed the day in a hangar without
/// signal can check that nothing was lost.
///
/// It is also the only place hours leave the device: "Upload" sends every
/// finished session that is still waiting (ADR 0015). Running timers stay,
/// because they are not finished yet.
struct SyncView: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(SyncCoordinator.self) private var sync

    @Query private var sessions: [WorkSession]
    @Query private var members: [Member]
    @Query private var settings: [AppSettings]
    /// The screen's width, to decide whether the status card fits beside the
    /// two columns of tiles.
    @State private var width: CGFloat = 0
    @Query private var tasks: [TaskDefinition]
    @Query private var aircraft: [Aircraft]

    var body: some View {
        ScrollView {
            // Chosen from the width rather than `ViewThatFits`: a grid has no
            // natural width to measure, so the old fit test left the content
            // narrower than the screen.
            Group {
                if !isSideBySide {
                    VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                        statusColumn
                        listColumn
                    }
                } else {
                    HStack(alignment: .top, spacing: metrics.sectionSpacing) {
                        statusColumn
                            .frame(width: 380)
                        VStack(alignment: .leading, spacing: metrics.sectionSpacing) { listColumn }
                    }
                }
            }
            .padding(metrics.gutter)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        // Edge to edge, under the navigation bar too, so no white strip shows
        // beside or above the content.
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
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
            .accessibilityElement(children: .combine)

            // Top-aligned: "3 hrs, 31 min" may wrap where "2" does not, and the
            // titles should still line up.
            HStack(alignment: .top, spacing: 10) {
                StatCard(
                    title: String(localized: "Sessions waiting"),
                    value: waiting.count.formatted()
                )
                StatCard(
                    title: String(localized: "Hours waiting"),
                    value: HoursFormatter.durationText(minutes: waitingMinutes, locale: locale)
                )
            }

            uploadButton

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

    /// The screen's one action, coloured like "Start" and "Stop and save":
    /// uploading is a deliberate step now, not something to retry. A standard
    /// button size, like every button in the app.
    private var uploadButton: some View {
        Button {
            Task { await sync.uploadNow() }
        } label: {
            Group {
                if sync.isSyncing {
                    ProgressView()
                } else {
                    Label {
                        waiting.isEmpty
                            ? Text("Upload")
                            : Text("Upload ^[\(waiting.count) session](inflect: true)")
                    } icon: {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                }
            }
        }
        .buttonStyle(.glassProminent)
        .disabled(sync.isSyncing || waiting.isEmpty)
        .accessibilityHint(Text("Sends the finished hours to zweef.app"))
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

    /// Two columns of tiles, except where one is all a tile has room for.
    private var gridColumns: [GridItem] {
        let isNarrow = horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
        return Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: isNarrow ? 1 : 2)
    }

    /// The status card beside the tiles only when two tiles still get about
    /// 280 pt each next to it — an iPad in landscape. In portrait the card
    /// goes on top, and the tiles get the full width.
    private var isSideBySide: Bool {
        horizontalSizeClass != .compact
            && !dynamicTypeSize.isAccessibilitySize
            && width >= 380 + 2 * 280 + 10 + metrics.sectionSpacing + 2 * metrics.gutter
    }

    /// The same tiles as the home screen, with a session in each tile instead
    /// of a member.
    private func group(title: Text, sessions: [WorkSession], showsReason: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            title
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(sessions) { session in
                    SessionTile(
                        session: session,
                        member: members.first { $0.zweefId == session.memberId },
                        task: tasks.first { $0.key == session.taskKey },
                        aircraft: aircraft.first { $0.zweefId == session.aircraftId },
                        showsReason: showsReason
                    )
                }
            }
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

    /// Why the hours are where they are. They wait until someone uploads
    /// them (ADR 0015), so the screen says so rather than implying a fault.
    private var statusDetail: Text {
        if let error = sync.lastOutcome?.error {
            switch error {
            case .notAuthorised:
                return Text("Connection refused: check the API key in Settings")
            case .rejected:
                return Text("zweef.app refused one of the registrations")
            default:
                return Text("The hours stay on this device until the connection returns.")
            }
        }
        if !sync.isConnected {
            return Text("The hours stay on this device until the connection returns.")
        }
        if waiting.isEmpty {
            return Text("Everything is in zweef.app.")
        }
        return Text("Nothing is sent by itself. Upload when the hours are complete.")
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
