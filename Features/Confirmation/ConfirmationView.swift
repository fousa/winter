import SwiftUI

/// The card after a stop: it says the hours were saved, and offers to take
/// the stop back.
///
/// Only stops get one. A start already shows itself — the tile moves into
/// "Working now" with its clock running — while a stop ends with the hours
/// going away from the screen, so the member wants to see what was saved.
///
/// It stays until someone taps outside it, with no timer and no Done button:
/// the summary is worth reading, and a card that closed by itself took the
/// undo with it before anyone had finished reading.
struct ConfirmationView: View {
    @Environment(\.metrics) private var metrics

    let confirmation: HomeModel.Confirmation
    var onUndo: () -> Void
    /// For VoiceOver's escape gesture; sighted users tap outside the card.
    var onDismiss: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "checkmark")
                    .scaledFont(size: 44, relativeTo: .largeTitle, weight: .semibold)
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(Color.runningTimer.gradient, in: .circle)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("Thanks, \(confirmation.memberName)")
                        .font(.title.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(confirmation.summary)
                        .font(.title3)
                        .foregroundStyle(.supporting)
                        .multilineTextAlignment(.center)
                }

                Button("Undo", systemImage: "arrow.uturn.backward", action: onUndo)
                    .frame(minHeight: LayoutMetrics.minimumTapTarget)
                    .buttonStyle(.glass)
                    .accessibilityHint(Text("Sets the timer running again"))

                Text("Tap outside to close")
                    .font(.footnote)
                    .foregroundStyle(.supporting)
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onDismiss)
    }
}

#Preview("Stopped") {
    ConfirmationView(
        confirmation: HomeModel.Confirmation(
            sessionId: UUID(),
            memberName: "Jan",
            summary: "2 hrs, 18 min · Hangar and workshop"
        ),
        onUndo: {},
        onDismiss: {}
    )
    .resolvedLayoutMetrics()
}

#Preview("Stopped · French") {
    ConfirmationView(
        confirmation: HomeModel.Confirmation(
            sessionId: UUID(),
            memberName: "Jan",
            summary: "2 h 18 min · Planeur · ASK 21"
        ),
        onUndo: {},
        onDismiss: {}
    )
    .environment(\.locale, Locale(identifier: "fr"))
    .resolvedLayoutMetrics()
}
