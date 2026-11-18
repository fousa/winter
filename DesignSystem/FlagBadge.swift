import SwiftUI

/// A session flag as an orange capsule.
///
/// Orange, never red: a flag is something for the board to look at, not an
/// error the member has to fix.
struct FlagBadge: View {
    let flag: SessionFlag

    var body: some View {
        Label(flag.badgeText, systemImage: flag.symbolName)
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.flagBackground, in: .capsule)
            .foregroundStyle(Color.flag)
    }
}

extension SessionFlag {
    /// The UI wording, in the device's language. Flags stay on the device:
    /// the registration in zweef.app carries only the times and the comment
    /// (ADR 0019).
    var badgeText: String {
        switch self {
        case .shortSession: String(localized: "Short session")
        case .longSession: String(localized: "Long session")
        case .stoppedAutomatically: String(localized: "Stopped automatically")
        case .endedOnBreak: String(localized: "Ended on a break")
        case .stoppedBySomeoneElse: String(localized: "Stopped by someone else")
        }
    }

    var symbolName: String {
        switch self {
        case .shortSession: "hourglass.bottomhalf.filled"
        case .longSession: "hourglass.tophalf.filled"
        case .stoppedAutomatically: "moon.zzz"
        case .endedOnBreak: "pause.circle"
        case .stoppedBySomeoneElse: "person.2"
        }
    }
}

/// How long the breaks in a session took, as a grey capsule: "30 min break".
///
/// Grey where a flag is orange, because a break is not something for the
/// board to look into — it is just why the hours are fewer than the times
/// suggest (ADR 0022).
struct BreakBadge: View {
    @Environment(\.locale) private var locale

    let minutes: Minutes

    var body: some View {
        Label {
            Text("\(HoursFormatter.durationText(minutes: minutes, locale: locale)) break")
        } icon: {
            Image(systemName: "pause.fill")
        }
        .font(.caption.weight(.medium))
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemFill), in: .capsule)
        .foregroundStyle(.supporting)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(SessionFlag.allCases, id: \.self) { flag in
            FlagBadge(flag: flag)
        }
        BreakBadge(minutes: 30)
    }
    .padding()
}
