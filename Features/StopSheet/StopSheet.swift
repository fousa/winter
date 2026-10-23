import SwiftData
import SwiftUI

/// The second of the two taps that end an hour, and the only place the app asks
/// what someone was doing.
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
    var onStop: (Material?, String?) -> Void
    var onDiscard: () -> Void
    var onDismiss: () -> Void

    @State private var selectedMaterial: Material?
    @State private var isPickingMaterial = false
    @State private var comment = ""
    @State private var isConfirmingStop = false
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    person
                    workDetails
                }
                .padding(metrics.gutter)
            }
            .navigationTitle("Stop")
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
            // `-sampleAlert stop` or `delete`, with `-sampleScreen stop`: opens
            // the confirmation as if the button had been tapped, so it can be
            // looked at on a simulator (CONTRIBUTING.md).
            .task {
                let arguments = ProcessInfo.processInfo.arguments
                guard let index = arguments.firstIndex(of: "-sampleAlert"), arguments.indices.contains(index + 1) else { return }
                try? await Task.sleep(for: .milliseconds(600))
                switch arguments[index + 1] {
                case "stop": isConfirmingStop = true
                case "delete": isConfirmingDelete = true
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
                        Text("Working since \(session.start.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.supporting)
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
                    .foregroundStyle(.supporting)
            }
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

    private func stop() {
        onStop(selectedMaterial, comment)
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

/// Builds a sheet from the sample club, so the previews share one setup.
private struct StopSheetPreview: View {
    var body: some View {
        let container = try! SampleData.container(runningSessionCount: 1)
        let context = container.mainContext
        let session = try! context.fetch(FetchDescriptor<WorkSession>()).first!
        let member = try! context.fetch(FetchDescriptor<Member>()).first { $0.zweefId == session.memberId }
        let material = try! context.fetch(FetchDescriptor<Material>())

        return StopSheet(
            session: session,
            member: member,
            material: material,
            onStop: { _, _ in },
            onDiscard: {},
            onDismiss: {}
        )
        .modelContainer(container)
    }
}
