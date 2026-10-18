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
            .background(Color.flag.opacity(0.15), in: .capsule)
            .foregroundStyle(Color.flag.mix(with: .black, by: 0.25))
    }
}

extension SessionFlag {
    /// The UI wording, in the device's language.
    ///
    /// Deliberately separate from ``ReportingLanguage/label(for:)``: what a
    /// member reads follows their device, while what is uploaded to zweef.app
    /// follows the club's reporting language (ADR 0010).
    var badgeText: String {
        switch self {
        case .shortSession: String(localized: "Short session")
        case .longSession: String(localized: "Long session")
        case .stoppedAutomatically: String(localized: "Stopped automatically")
        case .stoppedBySomeoneElse: String(localized: "Stopped by someone else")
        }
    }

    var symbolName: String {
        switch self {
        case .shortSession: "hourglass.bottomhalf.filled"
        case .longSession: "hourglass.tophalf.filled"
        case .stoppedAutomatically: "moon.zzz"
        case .stoppedBySomeoneElse: "person.2"
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(SessionFlag.allCases, id: \.self) { flag in
            FlagBadge(flag: flag)
        }
    }
    .padding()
}
