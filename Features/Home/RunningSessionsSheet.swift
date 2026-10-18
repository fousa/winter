import SwiftData
import SwiftUI

/// Which timer did you mean?
///
/// On a phone the floating bar is one row, so with several timers running there
/// is nowhere to put the cards that a tablet shows. Rather than guessing the
/// first one — and stopping the wrong member's hours — the bar asks here.
struct RunningSessionsSheet: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.dismiss) private var dismiss

    let sessions: [WorkSession]
    let members: [Int: Member]
    var onSelect: (WorkSession) -> Void

    var body: some View {
        NavigationStack {
            List(sessions) { session in
                Button {
                    onSelect(session)
                } label: {
                    HStack(spacing: 12) {
                        if let member = members[session.memberId] {
                            MemberAvatar(member: member, size: metrics.avatarSize)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.fullName)
                                    .font(.headline)
                                Text("since \(session.start.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        RunningTimerText(start: session.start, size: metrics.timerFontSize)
                    }
                    .frame(minHeight: LayoutMetrics.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens stopping"))
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Working now")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .resolvedLayoutMetrics()
    }
}

#Preview {
    RunningSessionsPreview()
}

private struct RunningSessionsPreview: View {
    var body: some View {
        let container = try! SampleData.container(runningSessionCount: 3)
        let context = container.mainContext
        let sessions = try! context.fetch(FetchDescriptor<WorkSession>(sortBy: [SortDescriptor(\.start)]))
        let members = try! context.fetch(FetchDescriptor<Member>())

        return RunningSessionsSheet(
            sessions: sessions,
            members: Dictionary(members.map { ($0.zweefId, $0) }, uniquingKeysWith: { a, _ in a }),
            onSelect: { _ in }
        )
        .modelContainer(container)
    }
}
