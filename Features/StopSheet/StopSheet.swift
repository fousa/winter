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
/// A form-sized sheet in one column on every device: the person, the running
/// time and the stop button on top — the button right under the time, since
/// that is what it stops — and the optional task grid underneath. Smaller
/// than a page sheet, so the home screen stays in view around it; it scrolls
/// when the text is large (ADR 0009).
struct StopSheet: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    let session: WorkSession
    let member: Member?
    let tasks: [TaskDefinition]
    let aircraft: [Aircraft]
    /// The club's setting: no stopping without a comment (ADR 0019).
    var requiresComment = false
    var onStop: (TaskDefinition?, Aircraft?, String?) -> Void
    var onDiscard: () -> Void
    var onDismiss: () -> Void

    @State private var selectedTask: TaskDefinition?
    @State private var selectedAircraft: Aircraft?
    @State private var isPickingAircraft = false
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    person
                    taskPicker
                }
                .padding(metrics.gutter)
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
        .presentationSizing(.form)
        .resolvedLayoutMetrics()
    }

    // MARK: - Person

    private var person: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let member {
                HStack(spacing: 14) {
                    MemberAvatar(member: member, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.fullName)
                            .font(.title2.weight(.semibold))
                        Text("Working since \(session.start.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Written as everywhere else ("17m", "1h05m"), so it needs no
            // "hours : minutes" caption to be read.
            // Two thirds of the display size: big enough to read from a step
            // back, small enough that the form sheet needs no scroll.
            RunningTimerText(start: session.start, size: metrics.displayTimerFontSize * 0.7)

            stopButton

            if isMissingComment {
                // Said next to the disabled button, so nobody wonders why it
                // does nothing; the field itself is under the tasks.
                Label("Add a comment below to stop", systemImage: "text.bubble")
                    .font(.footnote)
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
        }
        .menuStyle(.button)
        .disabled(isMissingComment)
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

    // MARK: - Task

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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(tasks) { task in
                    taskTile(task)
                }
            }

            if selectedTask?.asksForAircraft == true, !aircraft.isEmpty {
                aircraftTile
            }

            commentField

            Text("Saved on this device, with or without internet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// A task as a glass tile, like the members on the home screen: these are
    /// the buttons of this half of the sheet (ADR 0014). The chosen one takes
    /// on its own colour and a checkmark.
    private func taskTile(_ task: TaskDefinition) -> some View {
        let isSelected = selectedTask?.key == task.key
        return Button {
            select(task)
        } label: {
            // Icon beside the label rather than above it: half the height,
            // which leaves the form sheet room for the comment field.
            HStack(spacing: 10) {
                Image(systemName: task.symbolName)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(task.color.gradient, in: .rect(cornerRadius: 9))
                Text(task.label)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: metrics.tileCornerRadius))
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(task.color.opacity(0.25)).interactive() : .regular.interactive(),
            in: .rect(cornerRadius: metrics.tileCornerRadius)
        )
        .accessibilityElement(children: .combine)
        // A checkmark is invisible to a listener; the trait is not.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The chosen aircraft under the grid, for the task that asks for one;
    /// tapping it opens the picker again.
    private var aircraftTile: some View {
        Button {
            isPickingAircraft = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "airplane")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    if let plane = selectedAircraft {
                        Text(plane.name)
                            .font(.headline)
                        if let type = plane.displayType {
                            Text(type)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Choose the aircraft")
                            .font(.headline)
                            .foregroundStyle(.tint)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: LayoutMetrics.minimumTapTarget + 16, alignment: .leading)
            .contentShape(.rect(cornerRadius: metrics.tileCornerRadius))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: metrics.tileCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the list of aircraft"))
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
            selectedTask?.asksForAircraft == true ? selectedAircraft : nil,
            comment
        )
        dismiss()
    }

    private var isMissingComment: Bool {
        requiresComment && comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// What the member wants the board to know, in their own words. It goes
    /// into the registration after the times (ADR 0019). A few lines that
    /// grow as they type, so the sheet keeps its size until someone writes a
    /// paragraph.
    private var commentField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(
                requiresComment ? "Comment" : "Comment (optional)",
                text: $comment,
                prompt: Text("What did you do? For the board in zweef.app"),
                axis: .vertical
            )
            .lineLimit(2...5)
            .padding(14)
            .background(Color.card, in: .rect(cornerRadius: metrics.tileCornerRadius))

            Text(requiresComment ? "Required by your club." : "Optional.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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
            onStop: { _, _, _ in },
            onDiscard: {},
            onDismiss: {}
        )
        .modelContainer(container)
    }
}
