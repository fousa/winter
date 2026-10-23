import SwiftUI

/// One member in the grid: tap it to start, or — while they work — to stop.
///
/// Interactive Liquid Glass, so a tile lifts and shimmers under a finger like
/// any other iOS 26 control: that is what says "tap me" on a shared device
/// where nobody reads instructions (ADR 0014). The whole tile is the button —
/// with dirty hands, a small target inside a tile is a missed tap.
///
/// The same tile serves both places a member appears: the alphabetical grid,
/// and the "Working now" section at the top, where it carries the running
/// time. A working member is only in the second, so there is one tile to tap.
struct MemberTile: View {
    @Environment(\.metrics) private var metrics

    let member: Member
    /// When this member's running session started, or nil if they are not
    /// working. Set, the tile shows the running time ("1h23m").
    var workingSince: Date?
    var action: () -> Void

    private var isWorking: Bool { workingSince != nil }

    var body: some View {
        Button(action: action) {
            Group {
                if let workingSince {
                    // Two rows: the name gets the tile's full width, and the
                    // time sits underneath at a size readable from a step back.
                    // Side by side, the time pushed the name down to an
                    // ellipsis.
                    VStack(alignment: .leading, spacing: 10) {
                        identity
                        RunningTimerText(start: workingSince, size: metrics.timerFontSize)
                    }
                    .padding(16)
                } else {
                    identity
                        .padding(.horizontal, 14)
                }
            }
            .frame(minHeight: metrics.tileHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: metrics.tileCornerRadius))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: metrics.tileCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isWorking
                ? Text("\(member.fullName), working now")
                : Text(member.fullName)
        )
        .accessibilityHint(isWorking ? Text("Opens stopping") : Text("Starts your hours"))
    }

    private var identity: some View {
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
        }
    }
}

#Preview {
    let member = Member(zweefId: 1, firstName: "Jan", lastName: "Verhoeven")
    return VStack {
        MemberTile(member: member) {}
        MemberTile(member: member, workingSince: .now.addingTimeInterval(-83 * 60)) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .resolvedLayoutMetrics()
}
