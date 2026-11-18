import SwiftUI

/// One member in the grid: tap it to start, or — while they work — to pause or
/// stop.
///
/// Interactive Liquid Glass, so a tile lifts and shimmers under a finger like
/// any other iOS 26 control: that is what says "tap me" on a shared device
/// where nobody reads instructions (ADR 0014). The whole tile is the button —
/// with dirty hands, a small target inside a tile is a missed tap.
///
/// The same tile serves both places a member appears: the alphabetical grid,
/// and the "Working now" section at the top, where it carries the running
/// time. A working member is only in the second, so there is one tile to tap.
///
/// A member on a break stays in "Working now": the time stands still, with a
/// pause mark and "On a break since 12:30" under it. After an hour the tile
/// turns orange and asks whether someone forgot to resume, because on a
/// shared device there is nobody to send a reminder to (ADR 0022).
struct MemberTile: View {
    @Environment(\.metrics) private var metrics

    let member: Member
    /// This member's running session as plain values, or nil if they are not
    /// working. Set, the tile shows the time worked ("1h23m").
    var working: SessionFacts?
    var action: () -> Void

    private var isWorking: Bool { working != nil }

    var body: some View {
        if let pausedAt = working?.pausedAt {
            // Checked twice a minute, so the tile changes when the hour is up
            // without anyone touching the screen.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                tile(pausedAt: pausedAt, now: context.date)
            }
        } else {
            tile(pausedAt: nil, now: .now)
        }
    }

    private func tile(pausedAt: Date?, now: Date) -> some View {
        let isLongBreak = pausedAt.map { SessionRules.isLongBreak(since: $0, now: now) } ?? false

        return Button(action: action) {
            Group {
                if let working {
                    // Two rows: the name gets the tile's full width, and the
                    // time sits underneath at a size readable from a step back.
                    // Side by side, the time pushed the name down to an
                    // ellipsis.
                    VStack(alignment: .leading, spacing: 10) {
                        identity
                        if let pausedAt {
                            pausedTime(working, since: pausedAt, now: now, isLongBreak: isLongBreak)
                        } else {
                            RunningTimerText(facts: working, size: metrics.timerFontSize)
                        }
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
        .glassEffect(
            // Tinted only once the break looks forgotten: an ordinary lunch
            // should not shout from the wall.
            .regular.tint(isLongBreak ? Color.orange.opacity(0.22) : nil).interactive(),
            in: .rect(cornerRadius: metrics.tileCornerRadius)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(pausedAt: pausedAt))
        .accessibilityHint(accessibilityHint(pausedAt: pausedAt))
    }

    /// The time standing still, a pause mark beside it, and underneath in
    /// words what is going on: colour and a glyph alone would not tell an
    /// older member why this timer is not moving.
    private func pausedTime(_ working: SessionFacts, since pausedAt: Date, now: Date, isLongBreak: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "pause.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.flag)
                    .accessibilityHidden(true)
                RunningTimerText(facts: working, size: metrics.timerFontSize)
                    .foregroundStyle(.supporting)
            }

            Group {
                if isLongBreak {
                    let length = HoursFormatter.compactDuration(
                        minutes: SessionRules.duration(start: pausedAt, stop: now)
                    )
                    Text("Break of \(length) · forgot to resume?")
                } else {
                    Text("On a break since \(pausedAt.formatted(date: .omitted, time: .shortened))")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.flag)
            // Wraps rather than truncating: in French, at a large text size,
            // this is the line that says what is wrong.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func accessibilityLabel(pausedAt: Date?) -> Text {
        if let pausedAt {
            return Text("\(member.fullName), on a break since \(pausedAt.formatted(date: .omitted, time: .shortened))")
        }
        return isWorking ? Text("\(member.fullName), working now") : Text(member.fullName)
    }

    private func accessibilityHint(pausedAt: Date?) -> Text {
        if pausedAt != nil { return Text("Opens resuming or stopping") }
        return isWorking ? Text("Opens stopping") : Text("Starts your hours")
    }

    private var identity: some View {
        HStack(spacing: 12) {
            MemberAvatar(member: member, size: metrics.avatarSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(member.firstName)
                    .font(.headline)
                    .lineLimit(1)
                // The same size as the first name, a weight lighter: a last
                // name is read as often as a first name, by people whose eyes
                // are not what they were.
                Text(member.lastName)
                    .font(.body)
                    .foregroundStyle(.supporting)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    let member = Member(zweefId: 1, firstName: "Jan", lastName: "Verhoeven")
    let start = Date.now.addingTimeInterval(-5 * 3600)
    return VStack {
        MemberTile(member: member) {}
        MemberTile(member: member, working: SessionFacts(start: .now.addingTimeInterval(-83 * 60))) {}
        MemberTile(member: member, working: SessionFacts(start: start, pausedAt: .now.addingTimeInterval(-12 * 60))) {}
        MemberTile(member: member, working: SessionFacts(start: start, pausedAt: .now.addingTimeInterval(-95 * 60))) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .resolvedLayoutMetrics()
}
