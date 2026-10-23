import SwiftUI

/// One member in the grid: tap it to start, or — while they work — to stop.
///
/// Interactive Liquid Glass, so a tile lifts and shimmers under a finger like
/// any other iOS 26 control: that is what says "tap me" on a shared device
/// where nobody reads instructions (ADR 0014). The whole tile is the button —
/// with dirty hands, a small target inside a tile is a missed tap.
///
/// The same tile serves both places a member appears: the alphabetical grid,
/// where a working member gets a small stopwatch, and the "Working now"
/// section at the top, where the stopwatch becomes the running time.
struct MemberTile: View {
    @Environment(\.metrics) private var metrics

    let member: Member
    /// When this member's running session started, or nil if they are not
    /// working.
    var workingSince: Date?
    /// Show the running time ("01h23m") instead of the stopwatch glyph.
    var showsTimer = false
    var action: () -> Void

    private var isWorking: Bool { workingSince != nil }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                MemberAvatar(member: member, size: metrics.avatarSize)

                VStack(alignment: .leading, spacing: 1) {
                    Text(member.firstName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(member.lastName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let workingSince {
                    if showsTimer {
                        RunningTimerText(
                            start: workingSince,
                            size: metrics.timerFontSize * 0.75,
                            style: .hoursMinutes
                        )
                        // The time must survive a narrow tile; a long surname
                        // may truncate instead.
                        .layoutPriority(1)
                    } else {
                        Image(systemName: "stopwatch")
                            .foregroundStyle(.runningTimer)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: metrics.tileHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: metrics.tileCornerRadius))
        }
        .buttonStyle(.plain)
        .glassEffect(glass, in: .rect(cornerRadius: metrics.tileCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isWorking
                ? Text("\(member.fullName), working now")
                : Text(member.fullName)
        )
        .accessibilityHint(isWorking ? Text("Opens stopping") : Text("Starts your hours"))
    }

    /// A faint green tint on the running tiles at the top, so the section
    /// reads as "these are going" before a single number is read.
    private var glass: Glass {
        showsTimer && isWorking
            ? .regular.tint(Color.runningTimer.opacity(0.12)).interactive()
            : .regular.interactive()
    }
}

#Preview {
    let member = Member(zweefId: 1, firstName: "Jan", lastName: "Verhoeven")
    return VStack {
        MemberTile(member: member) {}
        MemberTile(member: member, workingSince: .now.addingTimeInterval(-83 * 60)) {}
        MemberTile(member: member, workingSince: .now.addingTimeInterval(-83 * 60), showsTimer: true) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .resolvedLayoutMetrics()
}
