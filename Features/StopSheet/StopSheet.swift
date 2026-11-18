import SwiftData
import SwiftUI

/// The second of the two taps that end an hour — or pause it — and the only
/// place the app asks what someone was doing.
///
/// Titled "Timer" rather than "Stop" since it also pauses and resumes
/// (ADR 0022). "Pause" sits beside "Stop and save" as the quieter of the two;
/// on a paused timer "Resume" takes the lead instead. A break that has gone
/// on for an hour is probably a forgotten resume, so the sheet then asks how
/// long the break really was before anything is saved.
///
/// It is also where a timer that should never have run is thrown away:
/// "Delete" in the toolbar removes the session from the device without saving
/// it. Deliberately not a second big button — stopping is the normal path,
/// deleting the exception.
///
/// Both ask first, in an alert: the question in the middle of the screen with
/// two full-width buttons. Not a menu by the button, which older members
/// missed or closed by accident, and not a confirmation dialog, whose popover
/// anchored away from the button on the wide sheet.
///
/// A form-sized sheet in one column on every device: the person, the running
/// time and the stop button on top — the button right under the time, since
/// that is what it stops — and underneath, what the work was on and a
/// comment, both optional unless the club requires the comment. Smaller
/// than a page sheet, so the home screen stays in view around it; it scrolls
/// when the text is large (ADR 0009).
struct StopSheet: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    let session: WorkSession
    let member: Member?
    /// zweef.app's material the club can book on, already filtered to what
    /// is offered (ADR 0020).
    let material: [Material]
    /// The club's setting: no stopping without a comment (ADR 0019).
    var requiresComment = false
    /// The material, the comment, and — for a break that was left running —
    /// how long it really was, when the member said so.
    var onStop: (Material?, String?, Minutes?) -> Void
    var onPause: () -> Void
    /// The same length, when the member goes back to work instead.
    var onResume: (Minutes?) -> Void
    var onDiscard: () -> Void
    var onDismiss: () -> Void

    @State private var selectedMaterial: Material?
    @State private var isPickingMaterial = false
    @State private var comment = ""
    @State private var isConfirmingStop = false
    @State private var isConfirmingDelete = false
    /// How long a forgotten break really was, in minutes; nil for "still on a
    /// break", which is also what an ordinary break is.
    @State private var countedBreak: Minutes?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    person
                    workDetails
                }
                .padding(metrics.gutter)
            }
            .navigationTitle("Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // The word, not a trash can: an icon alone meant nothing
                    // to older members.
                    Button("Delete") { isConfirmingDelete = true }
                        .accessibilityHint(Text("Removes this timer without saving it"))
                }
            }
            .alert(isShortSession ? shortSessionQuestion : stopQuestion, isPresented: $isConfirmingStop) {
                Button("Stop and save") { stop() }
                Button("Keep working", role: .cancel) {}
            } message: {
                if isShortSession {
                    Text("That looks short. Saving it is fine — the board sees it marked as a short session.")
                }
            }
            #if DEBUG
            // `-sampleAlert stop`, `delete` or `picker`, with `-sampleScreen
            // stop`: opens the confirmation or the material picker as if the
            // button had been tapped, so it can be looked at on a simulator
            // (CONTRIBUTING.md).
            .task {
                let arguments = ProcessInfo.processInfo.arguments
                // `-sampleFilled`: an aircraft and a comment already filled
                // in, as for an App Store screenshot.
                if arguments.contains("-sampleFilled") {
                    selectedMaterial = material.first { $0.kind == .flying }
                    comment = "Replaced the canopy seal and checked the tow release."
                }
                guard let index = arguments.firstIndex(of: "-sampleAlert"), arguments.indices.contains(index + 1) else { return }
                try? await Task.sleep(for: .milliseconds(600))
                switch arguments[index + 1] {
                case "stop": isConfirmingStop = true
                case "delete": isConfirmingDelete = true
                case "picker": isPickingMaterial = true
                default: break
                }
            }
            #endif
            .alert(discardQuestion, isPresented: $isConfirmingDelete) {
                Button("Delete", role: .destructive) { discard() }
                Button("Keep working", role: .cancel) {}
            } message: {
                Text("Removed from this device, never sent to zweef.app")
            }
            .sheet(isPresented: $isPickingMaterial) {
                MaterialPicker(material: material, selected: selectedMaterial) { item in
                    selectedMaterial = item
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
                        status
                    }
                }
            }

            timer

            if isLongBreak {
                breakQuestion
            }

            // Side by side while they fit; stacked in French at a large text
            // size, where "Arrêter et enregistrer" alone fills the row.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { actions }
                VStack(alignment: .leading, spacing: 10) { actions }
            }

            hint
                .font(.footnote)
                .foregroundStyle(.supporting)
                .fixedSize(horizontal: false, vertical: true)

            if isMissingComment {
                // Said next to the disabled button, so nobody wonders why it
                // does nothing; the field itself is under the tasks.
                Label("Add a comment below to stop", systemImage: "text.bubble")
                    .font(.footnote)
                    .foregroundStyle(.supporting)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if let pausedAt = session.pausedAt {
            Text("On a break since \(pausedAt.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.flag)
        } else {
            Text("Working since \(session.start.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.supporting)
        }
    }

    /// Written as everywhere else ("17m", "1h05m"), so it needs no
    /// "hours : minutes" caption to be read. Two thirds of the display size:
    /// big enough to read from a step back, small enough that the form sheet
    /// needs no scroll.
    ///
    /// On a break the time stands still, greyed, with a pause mark and what it
    /// is in words. Once the member has said how long a forgotten break
    /// really was, it shows what will be saved, and ticks again.
    private var timer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if isStandingStill {
                Image(systemName: "pause.circle.fill")
                    .font(.title)
                    .foregroundStyle(.flag)
                    .accessibilityHidden(true)
            }
            RunningTimerText(facts: shownFacts, size: metrics.displayTimerFontSize * 0.7)
                .foregroundStyle(isStandingStill ? Color.supporting : Color.primary)
            if isStandingStill {
                Text("worked so far")
                    .font(.subheadline)
                    .foregroundStyle(.supporting)
            }
        }
    }

    /// "Forgot to resume?" — shown once a break has lasted an hour.
    ///
    /// The answer is a length, not a clock time: nobody remembers that they
    /// were back at 13:20, everybody knows lunch took about three quarters of
    /// an hour. "Still on a break" is selected to begin with, so doing nothing
    /// invents no hours.
    private var breakQuestion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forgot to resume?")
                .font(.title3.weight(.semibold))
            Text("This break has lasted \(HoursFormatter.durationText(minutes: breakSoFar, locale: locale)). How long was it really?")
                .font(.subheadline)
                .foregroundStyle(.supporting)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    breakLengths
                    stillOnBreak
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) { breakLengths }
                    stillOnBreak
                }
                VStack(alignment: .leading, spacing: 8) {
                    breakLengths
                    stillOnBreak
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.flagBackground, in: .rect(cornerRadius: metrics.tileCornerRadius))
    }

    private var breakLengths: some View {
        ForEach(SessionRules.breakLengthsOffered, id: \.self) { minutes in
            choice(
                Text(HoursFormatter.durationText(minutes: minutes, locale: locale)),
                isSelected: countedBreak == minutes
            ) { countedBreak = minutes }
        }
    }

    private var stillOnBreak: some View {
        choice(Text("Still on a break"), isSelected: countedBreak == nil) { countedBreak = nil }
    }

    /// One answer to the question: filled when chosen, glass when not. Two
    /// buttons rather than one with a computed style, because the two styles
    /// are different types.
    @ViewBuilder
    private func choice(_ title: Text, isSelected: Bool, action: @escaping () -> Void) -> some View {
        if isSelected {
            Button(action: action) { title }
                .buttonStyle(.glassProminent)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: action) { title }
                .buttonStyle(.glass)
        }
    }

    /// "Stop and save" first while working, as it always was; "Resume" first
    /// on a break, because that is what someone coming back from lunch is
    /// here for.
    @ViewBuilder
    private var actions: some View {
        if session.isPaused {
            resumeButton
            stopButton
        } else {
            stopButton
            pauseButton
        }
    }

    /// Asks first (see the alert in `body`): a stopped timer is saved and on
    /// its way to the board, so one stray tap on a shared device should not
    /// do it.
    private var stopButton: some View {
        Button {
            isConfirmingStop = true
        } label: {
            Label("Stop and save", systemImage: "stop.fill")
        }
        .disabled(isMissingComment)
        .buttonStyle(.glassProminent)
        .tint(.stopAction)
    }

    /// No question asked: a pause saves nothing and is undone by "Resume".
    private var pauseButton: some View {
        Button {
            onPause()
            dismiss()
        } label: {
            Label("Pause", systemImage: "pause.fill")
        }
        .buttonStyle(.glass)
    }

    /// "Keep working" once a forgotten break has been given its length: the
    /// timer has in effect been running since, so there is nothing to resume.
    private var resumeButton: some View {
        Button {
            onResume(countedBreak)
            dismiss()
        } label: {
            if countedBreak == nil {
                Label("Resume", systemImage: "play.fill")
            } else {
                Label("Keep working", systemImage: "play.fill")
            }
        }
        .buttonStyle(.glassProminent)
    }

    /// What the buttons above will do, in a sentence: what a pause is for,
    /// and — on a break — exactly which times stopping would save.
    private var hint: Text {
        guard let pausedAt = session.pausedAt else {
            return Text("Going for lunch? Pause, and the break is not counted.")
        }
        guard let countedBreak else {
            return Text("Done for the day? Stopping now saves \(timeRange(to: pausedAt)).")
        }
        let length = HoursFormatter.durationText(minutes: countedBreak, locale: locale)
        return Text("Stopping now saves \(timeRange(to: .now)) with a break of \(length).")
    }

    /// "09:12–12:30", in the device's own way of writing a time.
    private func timeRange(to end: Date) -> String {
        let from = session.start.formatted(date: .omitted, time: .shortened)
        return "\(from)–\(end.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - What and why

    private var workDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("What did you work on?")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("Optional")
                    .font(.subheadline)
                    .foregroundStyle(.supporting)
            }

            if !material.isEmpty {
                materialRow
            }

            commentField

            Text("Saved on this device, with or without internet.")
                .font(.footnote)
                .foregroundStyle(.supporting)
        }
    }

    /// One glass row that opens zweef.app's list, and then shows the pick.
    /// A row rather than the list itself, so the form sheet stays small and
    /// the comment stays in view (ADR 0020).
    private var materialRow: some View {
        Button {
            isPickingMaterial = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: (selectedMaterial?.kind ?? .flying).symbolName)
                    .font(.title3)
                    .foregroundStyle(selectedMaterial == nil ? Color.supporting : Color.accentColor)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    if let item = selectedMaterial {
                        Text(item.name)
                            .font(.headline)
                        if let type = item.displayType {
                            Text(type)
                                .font(.subheadline)
                                .foregroundStyle(.supporting)
                        }
                    } else {
                        Text("Choose an aircraft, vehicle or project")
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
        .accessibilityHint(Text("Opens the list from zweef.app"))
    }

    // MARK: - Actions

    /// The session as the sheet shows it and as stopping would save it: with
    /// a forgotten break cut down to the length the member picked.
    private var shownFacts: SessionFacts {
        var facts = session.facts
        if let pausedAt = facts.pausedAt, let countedBreak {
            facts.breaks.append(
                WorkBreak(start: pausedAt, end: pausedAt.addingTimeInterval(Double(countedBreak) * 60))
            )
            facts.pausedAt = nil
        }
        return facts
    }

    /// On a break, and not told otherwise: the time shown does not move.
    private var isStandingStill: Bool {
        shownFacts.pausedAt != nil
    }

    private var breakSoFar: Minutes {
        guard let pausedAt = session.pausedAt else { return 0 }
        return SessionRules.duration(start: pausedAt, stop: .now)
    }

    private var isLongBreak: Bool {
        guard let pausedAt = session.pausedAt else { return false }
        return SessionRules.isLongBreak(since: pausedAt, now: .now)
    }

    /// The time worked that stopping now would save.
    private var workedMinutes: Minutes {
        SessionRules.workedMinutes(of: shownFacts, now: .now)
    }

    private var isShortSession: Bool {
        SessionRules.isShortSession(minutes: workedMinutes)
    }

    private var shortSessionQuestion: Text {
        Text("Is \(HoursFormatter.durationText(minutes: workedMinutes, locale: locale)) right?")
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

    private func stop() {
        onStop(selectedMaterial, comment, countedBreak)
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
                .foregroundStyle(.supporting)
        }
    }

    private func discard() {
        onDiscard()
        dismiss()
    }
}

extension MaterialKind {
    /// The symbol for each of zweef.app's tabs.
    var symbolName: String {
        switch self {
        case .flying: "airplane"
        case .rolling: "car"
        case .other: "square.grid.2x2"
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

#Preview("iPad · on a break", traits: .landscapeLeft) {
    StopSheetPreview(pausedMinutes: 12)
}

#Preview("iPhone · forgot to resume") {
    StopSheetPreview(pausedMinutes: 215)
}

#Preview("French · forgot to resume") {
    StopSheetPreview(pausedMinutes: 215)
        .environment(\.locale, Locale(identifier: "fr"))
}

/// Builds a sheet from the sample club, so the previews share one setup.
private struct StopSheetPreview: View {
    /// How long ago the member went on a break, or nil if they are working.
    var pausedMinutes: Int?

    var body: some View {
        let container = try! SampleData.container(runningSessionCount: 1, pausedMinutes: pausedMinutes)
        let context = container.mainContext
        let session = try! context.fetch(FetchDescriptor<WorkSession>()).first!
        let member = try! context.fetch(FetchDescriptor<Member>()).first { $0.zweefId == session.memberId }
        let material = try! context.fetch(FetchDescriptor<Material>())

        return StopSheet(
            session: session,
            member: member,
            material: material,
            onStop: { _, _, _ in },
            onPause: {},
            onResume: { _ in },
            onDiscard: {},
            onDismiss: {}
        )
        .modelContainer(container)
    }
}
