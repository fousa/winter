import SwiftData
import SwiftUI

/// The second of the two taps that end an hour, and the only place the app asks
/// what someone was doing.
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
    var onStop: (TaskDefinition?, Aircraft?, StoppedBy) -> Void
    var onDismiss: () -> Void

    @State private var selectedTask: TaskDefinition?
    @State private var selectedAircraft: Aircraft?
    @State private var stoppingForSomeoneElse = false
    @State private var isConfirmingShortSession = false

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
            }
            .confirmationDialog(
                shortSessionQuestion,
                isPresented: $isConfirmingShortSession,
                titleVisibility: .visible
            ) {
                Button("Stop and save") { stop() }
                Button("Keep working", role: .cancel) {}
            } message: {
                Text("That looks short. Saving it is fine — the board sees it marked as a short session.")
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

            Toggle("I'm stopping this for someone else", isOn: $stoppingForSomeoneElse)
                .font(.subheadline)
                .toggleStyle(.switch)
        }
    }

    private var stopButton: some View {
        Button {
            if isShortSession {
                isConfirmingShortSession = true
            } else {
                stop()
            }
        } label: {
            Label("Stop and save", systemImage: "stop.fill")
                .frame(maxWidth: .infinity, minHeight: metrics.primaryButtonHeight)
        }
        .buttonStyle(.glassProminent)
        .tint(.stopAction)
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

                    if task.key != tasks.last?.key {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(.background, in: .rect(cornerRadius: metrics.cardCornerRadius))

            if selectedTask?.asksForAircraft == true, !aircraft.isEmpty {
                aircraftPicker
            }

            Text("Saved on this device, with or without internet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var aircraftPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(aircraft) { plane in
                    aircraftChip(plane)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// The selected capsule is prominent, the rest are plain glass.
    ///
    /// Written as two branches rather than a ternary on `buttonStyle`, because
    /// the two styles are different concrete types.
    @ViewBuilder
    private func aircraftChip(_ plane: Aircraft) -> some View {
        let isSelected = selectedAircraft?.zweefId == plane.zweefId
        let chip = Button {
            selectedAircraft = isSelected ? nil : plane
        } label: {
            Text(plane.name)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .frame(minHeight: LayoutMetrics.minimumTapTarget)
        }

        if isSelected {
            chip.buttonStyle(.glassProminent)
        } else {
            chip.buttonStyle(.glass)
        }
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

    private func select(_ task: TaskDefinition) {
        if selectedTask?.key == task.key {
            selectedTask = nil
            selectedAircraft = nil
        } else {
            selectedTask = task
            if !task.asksForAircraft { selectedAircraft = nil }
        }
    }

    private func stop() {
        onStop(
            selectedTask,
            selectedTask?.asksForAircraft == true ? selectedAircraft : nil,
            stoppingForSomeoneElse ? .someoneElse : .member
        )
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
            onDismiss: {}
        )
        .modelContainer(container)
    }
}
