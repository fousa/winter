import SwiftUI

/// The card that says the tap landed, and offers to take it back.
///
/// It closes itself after three seconds, because nobody should have to dismiss
/// a receipt before walking to the workshop. Undo stays available for ten
/// seconds in total (`docs/spec.md`); once this card is gone, the rest of that
/// window lives on as a chip on the home screen.
struct ConfirmationView: View {
    @Environment(\.metrics) private var metrics

    let confirmation: HomeModel.Confirmation
    var onUndo: () -> Void
    var onDone: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(accent.gradient, in: .circle)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(detail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    Button("Undo", systemImage: "arrow.uturn.backward", action: onUndo)
                        .frame(minHeight: LayoutMetrics.minimumTapTarget)
                        .buttonStyle(.glass)

                    Button("Done", action: onDone)
                        .frame(minHeight: LayoutMetrics.minimumTapTarget)
                        .buttonStyle(.glassProminent)
                }

                Text("Closes by itself after 3 seconds")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            try? await Task.sleep(for: HomeModel.confirmationDuration)
            onDone()
        }
        .accessibilityAddTraits(.isModal)
    }

    private var accent: Color {
        confirmation.kind == .started ? .accentColor : .runningTimer
    }

    private var title: String {
        switch confirmation.kind {
        case .started: String(localized: "Enjoy the work, \(confirmation.memberName)")
        case .stopped: String(localized: "Thanks, \(confirmation.memberName)")
        }
    }

    private var detail: String {
        if let summary = confirmation.summary, !summary.isEmpty { return summary }
        return String(localized: "Started at \(Date.now.formatted(date: .omitted, time: .shortened))")
    }
}

#Preview("Started") {
    ConfirmationView(
        confirmation: HomeModel.Confirmation(kind: .started, sessionId: UUID(), memberName: "Ellen"),
        onUndo: {},
        onDone: {}
    )
    .resolvedLayoutMetrics()
}

#Preview("Stopped · French") {
    ConfirmationView(
        confirmation: HomeModel.Confirmation(
            kind: .stopped,
            sessionId: UUID(),
            memberName: "Jan",
            summary: "2 h 18 min · Planeur · ASK 21"
        ),
        onUndo: {},
        onDone: {}
    )
    .environment(\.locale, Locale(identifier: "fr"))
    .resolvedLayoutMetrics()
}
