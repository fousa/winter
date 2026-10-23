import SwiftUI

/// One finished session on the sync screen: who, when, how long, and on what.
///
/// Two fixed rows — who, when and how long on top, what underneath — so the
/// tiles line up in the grid whatever was filled in. The time is written as
/// on the home screen ("3h24m"). Opaque rather than glass: it is something to read, not to tap
/// (ADR 0014 keeps glass for the home screen's buttons).
struct SessionTile: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.locale) private var locale

    let session: WorkSession
    let member: Member?
    let material: Material?
    /// Shows why zweef.app refused it, for "Needs attention".
    var showsReason = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 1) {
                    Text(member?.fullName ?? String(localized: "Unknown member"))
                        .font(.headline)
                        .lineLimit(1)
                    Text(when)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Written the way the home screen writes a running time, so
                // "3h24m" means the same thing on both screens.
                if let minutes = session.minutes {
                    Text(HoursFormatter.compactDuration(minutes: minutes))
                        .scaledFont(size: metrics.timerFontSize, relativeTo: .title, weight: .semibold, design: .rounded)
                        .monospacedDigit()
                        .lineLimit(1)
                        .layoutPriority(1)
                        .accessibilityLabel(HoursFormatter.durationText(minutes: minutes, locale: locale))
                }
            }

            // Always there, one line, so every tile in the grid is the same
            // height and none is left saying nothing about the work.
            HStack(spacing: 8) {
                Text(what ?? String(localized: "Nothing chosen"))
                    .font(.subheadline)
                    .foregroundStyle(what == nil ? .secondary : .primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                ForEach(session.flags, id: \.self) { FlagBadge(flag: $0) }
            }
            // As tall as a flag badge, with or without one.
            .frame(minHeight: 30)

            if showsReason, let reason = session.lastError {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.flag)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: .rect(cornerRadius: metrics.tileCornerRadius))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatar: some View {
        if let member {
            MemberAvatar(member: member, size: metrics.avatarSize)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.secondary)
                .frame(width: metrics.avatarSize, height: metrics.avatarSize)
                .accessibilityHidden(true)
        }
    }

    /// "23 Oct · 09:12–11:30": no weekday, so the times still fit beside the
    /// duration in a portrait column.
    private var when: String {
        let day = session.start.formatted(.dateTime.day().month(.abbreviated).locale(locale))
        let start = session.start.formatted(date: .omitted, time: .shortened)
        guard let stop = session.stop?.formatted(date: .omitted, time: .shortened) else {
            return "\(day) · \(start)"
        }
        return "\(day) · \(start)–\(stop)"
    }

    /// "OO-ZXA", then the comment if there is one; nil when neither is there.
    private var what: String? {
        let parts = [material?.name, session.comment].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
