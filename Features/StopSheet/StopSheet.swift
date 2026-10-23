import SwiftData
import SwiftUI

/// The second of the two taps that end an hour, and the only place the app asks
/// what someone was doing.
///
/// It is also where a timer that should never have run is thrown away: a trash
/// menu in the toolbar deletes the session from the device without saving it.
/// A menu rather than a confirmation dialog, because the choice then sits on
/// the button that was tapped — a dialog anchors elsewhere on a wide sheet.
/// Deliberately not a second big button — stopping is the normal path,
/// deleting the exception.
///
/// Two columns in regular width — the person and the running clock on the left,
/// the optional task on the right — so stopping never needs a scroll. In
/// compact width, or at an accessibility text size, it becomes one scrolling
/// column with the stop button pinned at the bottom (ADR 0009).
struct StopSheet: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    let session: WorkSession
    let member: Member?
    let tasks: [TaskDefinition]
    let aircraft: [Aircraft]
    var onStop: (TaskDefinition?, Aircraft?) -> Void
    var onDiscard: () -> Void
    var onDismiss: () -> Void

    @State private var selectedTask: TaskDefinition?
    @State private var selectedAircraft: Aircraft?
    @State private var isPickingAircraft = false

    /// One column once the width is compact, and also once the text is large:
    /// two columns of accessibility-sized type fit nowhere.
    private var isSingleColumn: Bool {
        horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSingleColumn {
                    ScrollView {
                        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                            person
                            taskPicker
                        }
                        .padding(metrics.gutter)
                    }
                    .safeAreaInset(edge: .bottom) {
                        stopButton
                            .padding(metrics.gutter)
                            .background(.bar)
                    }
                } else {
                    HStack(alignment: .top, spacing: metrics.sectionSpacing) {
                        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                            person
                            Spacer(minLength: 0)
                            stopButton
                        }
                        .frame(maxWidth: 320)

                        ScrollView { taskPicker }
                    }
                    .padding(metrics.gutter)
                }
            }
            .navigationTitle("Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                        onDismiss()
                    }
                    .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    discardMenu
                }
            }
            .sheet(isPresented: $isPickingAircraft) {
                AircraftPicker(aircraft: aircraft, selected: selectedAircraft) { plane in
                    selectedAircraft = plane
                }
            }
        }
        .presentationSizing(.page)
        .resolvedLayoutMetrics()
    }

    // MARK: - Left column

    private var person: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let member {
                HStack(spacing: 14) {
                    MemberAvatar(member: member, size: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.fullName)
                            .font(.title2.weight(.semibold))
                        Text("Working since \(session.start.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                RunningTimerText(
                    start: session.start,
                    size: metrics.displayTimerFontSize,
                    weight: .light
                )
                Text("hours : minutes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A menu, like the trash button: the question as its header, the
    /// confirmation and a way out under the finger that tapped. A stopped
    /// timer is saved and on its way to the board, so one stray tap on a
    /// shared device should not do it. A short session asks whether the time
    /// is right instead, since that is the likelier mistake.
    private var stopButton: some View {
        Menu {
            Section {
                Button {
                    stop()
                } label: {
                    Label("Stop and save", systemImage: "stop.fill")
                    if isShortSession {
                        Text("That looks short. Saving it is fine — the board sees it marked as a short session.")
                    }
                }
                Button("Keep working", systemImage: "arrow.uturn.backward") {}
            } header: {
                isShortSession ? shortSessionQuestion : stopQuestion
            }
        } label: {
            Label("Stop and save", systemImage: "stop.fill")
                .frame(maxWidth: .infinity, minHeight: metrics.primaryButtonHeight)
        }
        .menuStyle(.button)
        .buttonStyle(.glassProminent)
        .tint(.stopAction)
    }

    /// The confirmation lives in the menu itself: the question as the section
    /// header, the consequence as the subtitle of the destructive item, and an
    /// explicit way out.
    private var discardMenu: some View {
        Menu {
            Section {
                Button(role: .destructive) {
                    discard()
                } label: {
                    Text("Delete")
                    Text("Removed from this device, never sent to zweef.app")
                }
                Button("Keep working", systemImage: "arrow.uturn.backward") {}
            } header: {
                discardQuestion
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .labelStyle(.iconOnly)
        .accessibilityHint(Text("Removes this timer without saving it"))
    }

    // MARK: - Right column

    private var taskPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("What were you working on?")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("Optional")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    Button {
                        select(task)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: task.symbolName)
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(task.color.gradient, in: .rect(cornerRadius: 8))
                            Text(task.label)
                            Spacer()
                            if selectedTask?.key == task.key {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: LayoutMetrics.minimumTapTarget + 8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    // A checkmark is invisible to a listener; the trait is not.
                    .accessibilityAddTraits(selectedTask?.key == task.key ? [.isSelected] : [])

                    if selectedTask?.key == task.key, task.asksForAircraft, !aircraft.isEmpty {
                        aircraftRow
                    }

                    if task.key != tasks.last?.key {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(.background, in: .rect(cornerRadius: metrics.cardCornerRadius))

            Text("Saved on this device, with or without internet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// The chosen aircraft, under the task that asks for one; tapping it
    /// opens the picker again.
    private var aircraftRow: some View {
        VStack(spacing: 0) {
            Divider().padding(.leading, 56)
            Button {
                isPickingAircraft = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let plane = selectedAircraft {
                            Text(plane.name)
                                .font(.body.weight(.medium))
                            if let type = plane.displayType {
                                Text(type)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Choose the aircraft")
                                .foregroundStyle(.tint)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 56)
                .padding(.trailing, 14)
                .padding(.vertical, 8)
                .frame(minHeight: LayoutMetrics.minimumTapTarget + 8)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Opens the list of aircraft"))
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Actions

    private var isShortSession: Bool {
        guard let minutes = SessionRules.duration(of: SessionFacts(start: session.start, stop: .now))
        else { return false }
        return SessionRules.isShortSession(minutes: minutes)
    }

    private var shortSessionQuestion: Text {
        let minutes = SessionRules.duration(start: session.start, stop: .now)
        return Text("Is \(HoursFormatter.durationText(minutes: minutes, locale: locale)) right?")
    }

    private var stopQuestion: Text {
        if let member {
            return Text("Stop \(member.firstName)'s timer?")
        }
        return Text("Stop this timer?")
    }

    private var discardQuestion: Text {
        if let member {
            return Text("Delete \(member.firstName)'s timer?")
        }
        return Text("Delete this timer?")
    }

    private func select(_ task: TaskDefinition) {
        // Animated, so the aircraft unfold under the task rather than appear.
        withAnimation(.smooth) {
            if selectedTask?.key == task.key {
                selectedTask = nil
                selectedAircraft = nil
            } else {
                selectedTask = task
                if !task.asksForAircraft { selectedAircraft = nil }
            }
        }
        // Picking Glider goes straight on to which one: that is the next
        // question anyway.
        if selectedTask?.key == task.key, task.asksForAircraft, !aircraft.isEmpty, selectedAircraft == nil {
            isPickingAircraft = true
        }
    }

    private func stop() {
        onStop(
            selectedTask,
            selectedTask?.asksForAircraft == true ? selectedAircraft : nil
        )
        dismiss()
    }

    private func discard() {
        onDiscard()
        dismiss()
    }
}

extension TaskDefinition {
    /// The task's colour, mapped from the stored name.
    ///
    /// Stored as a name rather than components so the list stays editable by a
    /// club without the app having to migrate colour data.
    var color: Color {
        switch colorName {
        case "blue": .blue
        case "orange": .orange
        case "purple": .purple
        case "green": .green
        case "teal": .teal
        case "pink": .pink
        case "indigo": .indigo
        default: .gray
        }
    }
}

#Preview("iPad · two columns", traits: .landscapeLeft) {
    StopSheetPreview()
}

#Preview("iPhone · one column") {
    StopSheetPreview()
}

#Preview("French") {
    StopSheetPreview()
        .environment(\.locale, Locale(identifier: "fr"))
}

/// Builds a sheet from the sample club, so the previews share one setup.
private struct StopSheetPreview: View {
    var body: some View {
        let container = try! SampleData.container(runningSessionCount: 1)
        let context = container.mainContext
        let session = try! context.fetch(FetchDescriptor<WorkSession>()).first!
        let member = try! context.fetch(FetchDescriptor<Member>()).first { $0.zweefId == session.memberId }
        let tasks = try! context.fetch(FetchDescriptor<TaskDefinition>(sortBy: [SortDescriptor(\.sortOrder)]))
        let planes = try! context.fetch(FetchDescriptor<Aircraft>(sortBy: [SortDescriptor(\.name)]))

        return StopSheet(
            session: session,
            member: member,
            tasks: tasks,
            aircraft: planes,
            onStop: { _, _ in },
            onDiscard: {},
            onDismiss: {}
        )
        .modelContainer(container)
    }
}
