import SwiftData
import SwiftUI

/// The screen the device sits on all day: who is here, who is working, and the
/// way into closing the day.
///
/// Two taps to start (a name, then Start) and two to stop (a card, then Stop
/// and save). Everything else — search, the letter index, the day overview — is
/// there to make those two taps land on the right person.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.metrics) private var metrics
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale

    @Query(filter: #Predicate<Member> { $0.isActive }) private var members: [Member]
    @Query private var sessions: [WorkSession]
    @Query(sort: \TaskDefinition.sortOrder) private var tasks: [TaskDefinition]
    @Query(sort: \Aircraft.name) private var aircraft: [Aircraft]
    @Query private var settings: [AppSettings]

    @State private var model = HomeModel()
    @State private var path: [Destination] = []

    /// The pushed screens.
    enum Destination: Hashable {
        case closeDay
        case sync
    }

    /// Writes go through here; it is a thin façade over the context, so making
    /// one per use costs nothing and always has the right context.
    private var store: SessionStore { SessionStore(context: context) }

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        NavigationStack(path: $path) {
            memberList
                .background(Color(.systemGroupedBackground))
                .navigationTitle(clubName)
                .navigationSubtitle(subtitle)
                .toolbar { toolbar }
                .searchable(text: $model.searchText, prompt: Text("Search members"))
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .closeDay: CloseDayView()
                    case .sync: SyncView()
                    }
                }
        }
        .sheet(item: sheetRoute) { route in
            sheet(for: route)
        }
        .overlay {
            // In regular width the confirmation is a card floating over dimmed
            // content, as in the mockups; in compact it is a sheet, which is
            // what a phone has room for.
            if case .confirmation(let confirmation) = model.route, !isCompact {
                confirmationCard(confirmation)
            }
        }
        .sensoryFeedback(.success, trigger: model.feedback)
        .keepScreenAwake(!runningSessions.isEmpty)
        .resolvedLayoutMetrics()
    }

    // MARK: - Content

    private var memberList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    if model.searchText.isEmpty, !oftenHere.isEmpty {
                        section(title: Text("Often here"), members: oftenHere)
                    }

                    if sections.isEmpty {
                        ContentUnavailableView.search(text: model.searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(sections) { group in
                            section(
                                title: model.searchText.isEmpty && !isCompact
                                    ? Text(verbatim: group.letter)
                                    : nil,
                                members: group.members
                            )
                            .id(group.letter)
                        }
                    }
                }
                .padding(.horizontal, metrics.gutter)
                .padding(.vertical, metrics.sectionSpacing)
            }
            .overlay(alignment: .trailing) {
                if model.searchText.isEmpty, sections.count > 1 {
                    LetterIndex(letters: sections.map(\.letter)) { letter in
                        withAnimation { proxy.scrollTo(letter, anchor: .top) }
                    }
                }
            }
        }
    }

    private func section(title: Text?, members: [Member]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                title
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: metrics.tileMinimumWidth), spacing: 10)],
                spacing: 10
            ) {
                ForEach(members) { member in
                    MemberTile(member: member, isWorking: isWorking(member)) {
                        tap(member)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let undo = model.pendingUndo {
                UndoChip(undo: undo) {
                    model.undo(undo, sessions: sessions, store: store)
                } onExpire: {
                    model.expireUndo()
                }
            }

            WorkingNowBar(
                sessions: runningSessions,
                members: membersById,
                onSelect: { model.route = .stop(sessionId: $0.id) },
                onSelectMany: { model.route = .runningList },
                onCloseDayHint: { if canCloseDay { path.append(.closeDay) } }
            )
        }
        .padding(.bottom, 8)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                path.append(.sync)
            } label: {
                Label {
                    Text("Sync")
                } icon: {
                    Image(systemName: pendingUploadCount > 0 ? "icloud.and.arrow.up" : "checkmark.icloud")
                }
            }
            .badge(pendingUploadCount)
            .accessibilityLabel(
                pendingUploadCount > 0
                    ? Text("^[\(pendingUploadCount) session](inflect: true) waiting to upload")
                    : Text("Everything uploaded")
            )
        }

        // On a phone the primary action belongs at the bottom, within reach.
        ToolbarItem(placement: isCompact ? .bottomBar : .topBarTrailing) {
            Button {
                path.append(.closeDay)
            } label: {
                Label {
                    Text("Close day")
                } icon: {
                    Image(systemName: canCloseDay ? "moon.stars" : "lock")
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(!canCloseDay)
            .accessibilityHint(
                canCloseDay
                    ? Text("Sends today's hours to zweef.app")
                    : Text("Stop the running timers first")
            )
        }
    }

    // MARK: - Presentation

    private var sheetRoute: Binding<HomeModel.Route?> {
        Binding {
            guard let route = model.route else { return nil }
            if case .confirmation = route, !isCompact { return nil }
            return route
        } set: { newValue in
            model.route = newValue
        }
    }

    @ViewBuilder
    private func sheet(for route: HomeModel.Route) -> some View {
        switch route {
        case .start(let memberId):
            if let member = membersById[memberId] {
                StartSheet(member: member) {
                    model.start(member: member, store: store)
                } onDismiss: {
                    model.route = nil
                }
            }

        case .stop(let sessionId):
            if let session = sessions.first(where: { $0.id == sessionId }) {
                StopSheet(
                    session: session,
                    member: membersById[session.memberId],
                    tasks: tasks.filter { !$0.isArchived },
                    aircraft: aircraft
                ) { task, plane, stoppedBy in
                    model.stop(
                        session,
                        member: membersById[session.memberId],
                        task: task,
                        aircraft: plane,
                        by: stoppedBy,
                        store: store,
                        locale: locale
                    )
                } onDismiss: {
                    model.route = nil
                }
            }

        case .runningList:
            RunningSessionsSheet(sessions: runningSessions, members: membersById) { session in
                model.route = .stop(sessionId: session.id)
            }

        case .confirmation(let confirmation):
            ConfirmationView(confirmation: confirmation) {
                if let undo = model.pendingUndo {
                    model.undo(undo, sessions: sessions, store: store)
                }
            } onDone: {
                model.route = nil
            }
            .presentationDetents([.medium])
        }
    }

    private func confirmationCard(_ confirmation: HomeModel.Confirmation) -> some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { model.route = nil }

            ConfirmationView(confirmation: confirmation) {
                if let undo = model.pendingUndo {
                    model.undo(undo, sessions: sessions, store: store)
                }
            } onDone: {
                model.route = nil
            }
            .frame(maxWidth: 480)
        }
        .transition(.opacity)
    }

    // MARK: - Derived state

    private var runningSessions: [WorkSession] {
        sessions.filter { $0.status == .running }.sorted { $0.start < $1.start }
    }

    private var pendingUploadCount: Int {
        sessions.filter { $0.status == .completed && ($0.syncState == .local || $0.syncState == .ready) }.count
    }

    private var canCloseDay: Bool {
        model.canCloseDay(runningCount: runningSessions.count)
    }

    private var membersById: [Int: Member] {
        Dictionary(members.map { ($0.zweefId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var sections: [MemberSection<Member>] {
        MemberDirectory.sections(for: MemberDirectory.search(members, query: model.searchText))
    }

    private var oftenHere: [Member] {
        MemberDirectory.oftenHere(from: members, sessionCounts: model.sessionCounts(for: sessions))
    }

    private var clubName: String {
        // Typed during setup or fetched from zweef.app, falling back to the
        // app's own name (ADR 0012).
        ClubName.display(stored: settings.first?.clubName)
    }

    private var subtitle: String {
        let today = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return String(localized: "Maintenance hours · \(today) · tap your name to start")
    }

    private func isWorking(_ member: Member) -> Bool {
        runningSessions.contains { $0.memberId == member.zweefId }
    }

    private func tap(_ member: Member) {
        if let running = runningSessions.first(where: { $0.memberId == member.zweefId }) {
            model.route = .stop(sessionId: running.id)
        } else {
            model.route = .start(memberId: member.zweefId)
        }
    }
}

#Preview("iPad · nobody working", traits: .landscapeLeft) {
    let container = try! SampleData.container()
    HomeView()
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container))
}

#Preview("iPad · two working", traits: .landscapeLeft) {
    let container = try! SampleData.container(runningSessionCount: 2)
    HomeView()
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container))
}

#Preview("iPad · busy", traits: .landscapeLeft) {
    let container = try! SampleData.container(runningSessionCount: 6)
    HomeView()
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container))
}

#Preview("iPhone · two working") {
    let container = try! SampleData.container(runningSessionCount: 2)
    HomeView()
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container))
}

#Preview("French · accessibility size") {
    let container = try! SampleData.container(runningSessionCount: 2)
    HomeView()
        .modelContainer(container)
        .environment(SyncCoordinator.preview(container: container))
        .environment(\.locale, Locale(identifier: "fr"))
        .environment(\.dynamicTypeSize, .accessibility3)
}
