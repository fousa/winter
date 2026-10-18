import SwiftUI

/// The floating bar that shows who is working, and is how anyone stops a timer.
///
/// Three shapes, because a club has quiet evenings and work days: nobody
/// working, a few people as large cards, or a grid of compact cards once there
/// are four or more. In a compact size class it collapses to one row that opens
/// the list as a sheet — a phone has no room for a bar that covers a third of
/// the screen (ADR 0009).
///
/// The wording is about *this device* on purpose: a timer started on the
/// workshop iPad cannot be seen here, because zweef.app has no notion of a
/// running timer to sync one through.
struct WorkingNowBar: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let sessions: [WorkSession]
    let members: [Int: Member]
    var onSelect: (WorkSession) -> Void
    /// Compact width with more than one timer running: ask which one.
    var onSelectMany: () -> Void
    var onCloseDayHint: () -> Void

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        GlassBar {
            if isCompact {
                compactSummary
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if !sessions.isEmpty { cards }
                }
            }
        }
    }

    // MARK: - Regular width

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(sessions.isEmpty ? Color.secondary.opacity(0.5) : .runningTimer)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text("Working now")
                    .font(.headline)
                if sessions.isEmpty {
                    Text("Nobody on this device")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("^[\(sessions.count) member](inflect: true)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if sessions.isEmpty {
                Button("Last one out? Close the day.", action: onCloseDayHint)
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap to stop")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var cards: some View {
        if sessions.count <= 3 {
            HStack(spacing: 12) {
                ForEach(sessions) { session in
                    card(for: session, compact: false)
                }
            }
        } else {
            // Four or more: compact cards in a grid that grows in height
            // instead of shrinking each card into unreadability.
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(sessions) { session in
                    card(for: session, compact: true)
                }
            }
        }
    }

    private func card(for session: WorkSession, compact: Bool) -> some View {
        Button {
            onSelect(session)
        } label: {
            HStack(spacing: 10) {
                if let member = members[session.memberId] {
                    MemberAvatar(member: member, size: compact ? 40 : metrics.barAvatarSize)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(compact ? member.shortName : member.fullName)
                            .font(compact ? .subheadline.weight(.medium) : .headline)
                            .lineLimit(1)
                        if !compact {
                            Text("since \(session.start.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                RunningTimerText(
                    start: session.start,
                    size: compact ? metrics.timerFontSize * 0.8 : metrics.timerFontSize
                )
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.background.opacity(0.7), in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens stopping"))
    }

    // MARK: - Compact width

    private var compactSummary: some View {
        Button {
            switch sessions.count {
            case 0: onCloseDayHint()
            case 1: onSelect(sessions[0])
            // More than one running and no room to show them: a sheet asks
            // which timer was meant, instead of guessing the first.
            default: onSelectMany()
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(sessions.isEmpty ? Color.secondary.opacity(0.5) : .runningTimer)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Working now")
                        .font(.subheadline.weight(.semibold))
                    (sessions.isEmpty
                        ? Text("Nobody on this device")
                        : Text("^[\(sessions.count) member](inflect: true) · tap to stop"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if let next = sessions.first {
                    RunningTimerText(start: next.start, size: metrics.timerFontSize)
                }
            }
            .frame(minHeight: LayoutMetrics.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }
}

extension Member {
    /// "Jan V." — for compact cards, where a full name would be clipped.
    var shortName: String {
        guard let initial = lastName.first else { return firstName }
        return "\(firstName) \(initial)."
    }
}
