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
    /// Ties a member's tile in "Working now" to their tile in the letter
    /// sections, so starting or stopping moves the tile instead of swapping it.
    @Namespace private var tiles

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
                .toolbar { toolbar }
                .searchable(text: $model.searchText, prompt: Text("Search members"))
                // A safe-area *bar*, not an inset: iOS 26 then draws the
                // scroll edge effect under the undo chip.
                .safeAreaBar(edge: .bottom, spacing: 0) { bottomBar }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .closeDay: CloseDayView()
                    case .sync: SyncView()
                    }
                }
        }
        .sheet(item: sheetRoute, onDismiss: {
            // The next screen waits for this one to be gone; see
            // `HomeModel.queuedRoute`.
            withAnimation(.smooth) { model.presentQueuedRoute() }
        }) { route in
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
        #if DEBUG
        .task { openSampleScreen() }
        #endif
        .keepScreenAwake(!runningSessions.isEmpty)
        .resolvedLayoutMetrics()
    }

    // MARK: - Content

    private var memberList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    // Who is working comes first, with their running time:
                    // stopping is the other half of what this screen is for.
                    // Searched like everyone else, so typing a name finds a
                    // member whether or not their timer is running.
                    if !workingNow.isEmpty {
                        workingNowSection
                    }

                    if model.searchText.isEmpty, !oftenHere.isEmpty {
                        section(title: Text("Recents"), members: oftenHere, movesTiles: false)
                    }

                    if sections.isEmpty, workingNow.isEmpty {
                        ContentUnavailableView.search(text: model.searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if !model.searchText.isEmpty {
                        // One titled section rather than letters: a handful of
                        // results needs no index, but under "Working now" it
                        // does need a name, or it reads as part of it.
                        if !sections.isEmpty {
                            section(title: Text("Members"), members: sections.flatMap(\.members))
                        }
                    } else {
                        ForEach(sections) { group in
                            section(
                                title: isCompact ? nil : Text(verbatim: group.letter),
                                members: group.members
                            )
                            .id(group.letter)
                        }
                    }
                }
                // Starting or stopping — from a sheet, an undo, or the closing
                // time — moves the tile between the sections in one motion.
                .animation(.smooth, value: runningSessions.map(\.id))
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

    /// - Parameter movesTiles: Whether these tiles take part in the move to
    ///   and from "Working now". Only one place per member may: "Recents"
    ///   repeats members from the letter sections, and a geometry group with
    ///   two tiles in it has no single place to fly from. Those tiles get an
    ///   id of their own, which matches nothing.
    private func section(title: Text?, members: [Member], movesTiles: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                sectionTitle(title)
            }
            tileGrid {
                ForEach(members) { member in
                    MemberTile(member: member) {
                        model.route = .start(memberId: member.zweefId)
                    }
                    .matchedGeometryEffect(
                        id: movesTiles ? AnyHashable(member.zweefId) : AnyHashable("often-\(member.zweefId)"),
                        in: tiles
                    )
                    .transition(tileTransition)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The running timers, oldest first, as tiles that show the time.
    private var workingNowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(Text("Working now"))
            tileGrid(minimumWidth: metrics.workingTileMinimumWidth) {
                ForEach(workingNow, id: \.session.id) { session, member in
                    MemberTile(member: member, workingSince: session.start) {
                        model.route = .stop(sessionId: session.id)
                    }
                    .matchedGeometryEffect(id: AnyHashable(member.zweefId), in: tiles)
                    .transition(tileTransition)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// For a tile with no counterpart on screen to move from — a section that
    /// is scrolled away, or a timer deleted outright.
    private var tileTransition: AnyTransition {
        .scale(scale: 0.85).combined(with: .opacity)
    }

    private func sectionTitle(_ title: Text) -> some View {
        title
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func tileGrid(
        minimumWidth: CGFloat? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimumWidth ?? metrics.tileMinimumWidth), spacing: 10)],
            spacing: 10,
            content: content
        )
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let undo = model.pendingUndo {
            UndoChip(undo: undo) {
                model.undoStart(undo, sessions: sessions, store: store)
            } onExpire: {
                model.expireUndo()
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Under the large title, at a size people can read from a step back;
        // `navigationSubtitle` renders it in caption type.
        ToolbarItem(placement: .largeSubtitle) {
            Text(subtitle)
                .font(isCompact ? .subheadline : .title3)
                .foregroundStyle(.secondary)
                // Wraps on a phone rather than cutting off "tap your name to
                // start", which is the instruction.
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

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
            // Icon only: "Sync" becomes "Synchronisation" in French, which does
            // not belong in a toolbar next to a search field. The meaning lives
            // in the accessibility label below instead.
            .labelStyle(.iconOnly)
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
                        // "Clôturer la journée" is twice the English. One line,
                        // shrink a little rather than wrap or truncate.
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } icon: {
                    Image(systemName: canCloseDay ? "moon.stars" : "lock")
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(!canCloseDay)
            .accessibilityHint(
                canCloseDay
                    ? Text("Checks and closes today's hours")
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
                ) { task, plane in
                    model.stop(
                        session,
                        member: membersById[session.memberId],
                        task: task,
                        aircraft: plane,
                        store: store,
                        locale: locale
                    )
                } onDiscard: {
                    model.discard(session, store: store)
                } onDismiss: {
                    model.route = nil
                }
            }

        case .confirmation(let confirmation):
            // Closed by a swipe or a tap above it, like any sheet.
            ConfirmationView(confirmation: confirmation) {
                model.undoStop(confirmation, sessions: sessions, store: store)
            } onDismiss: {
                model.route = nil
            }
            .presentationDetents([.medium])
        }
    }

    private func confirmationCard(_ confirmation: HomeModel.Confirmation) -> some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.smooth) { model.route = nil } }

            ConfirmationView(confirmation: confirmation) {
                withAnimation(.smooth) { model.undoStop(confirmation, sessions: sessions, store: store) }
            } onDismiss: {
                withAnimation(.smooth) { model.route = nil }
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

    /// The running timers that match the search, with their member.
    private var workingNow: [(session: WorkSession, member: Member)] {
        runningSessions.compactMap { session in
            guard let member = membersById[session.memberId],
                  MemberDirectory.matches(member, query: model.searchText)
            else { return nil }
            return (session, member)
        }
    }

    /// Everyone without a running timer: a working member's tile is in
    /// "Working now" only.
    private var idleMembers: [Member] {
        MemberDirectory.idle(members, workingIds: Set(runningSessions.map(\.memberId)))
    }

    private var sections: [MemberSection<Member>] {
        MemberDirectory.sections(for: MemberDirectory.search(idleMembers, query: model.searchText))
    }

    private var oftenHere: [Member] {
        MemberDirectory.oftenHere(from: idleMembers, sessionCounts: model.sessionCounts(for: sessions))
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

}

#if DEBUG
extension HomeView {
    /// `-sampleScreen sync`, `closeDay` or `stop`, next to `-sampleClub`:
    /// opens that screen on launch so it can be looked at on a simulator
    /// (CONTRIBUTING.md).
    fileprivate func openSampleScreen() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-sampleScreen"),
              arguments.indices.contains(index + 1)
        else { return }
        switch arguments[index + 1] {
        case "sync": path = [.sync]
        case "closeDay": path = [.closeDay]
        case "stop":
            if let session = runningSessions.first { model.route = .stop(sessionId: session.id) }
        default: break
        }
    }
}
#endif

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
