import SwiftUI

/// The second of the two taps that start an hour.
///
/// It exists for one reason: on a shared device the wrong name gets tapped, and
/// this is where that is caught. So the photo and the name are large; the way
/// out for a wrong name is the close button, like any other sheet.
///
/// What was worked on is not asked here. A member arriving with dirty hands
/// does not yet know what they will end up doing, and asking costs a tap that
/// ADR 0007 says we do not spend.
struct StartSheet: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.dismiss) private var dismiss

    let member: Member
    var onStart: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: metrics.sectionSpacing) {
                Spacer(minLength: 0)

                MemberAvatar(member: member, size: 120)

                VStack(spacing: 6) {
                    Text(member.fullName)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Ready to get going?")
                        .font(.title3)
                        .foregroundStyle(.supporting)
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        onStart()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.glassProminent)

                    Text("You pick what you worked on when you stop.")
                        .font(.footnote)
                        .foregroundStyle(.supporting)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(metrics.gutter)
            .navigationTitle("Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
        .presentationSizing(.form)
        .resolvedLayoutMetrics()
    }
}

#Preview("iPad", traits: .landscapeLeft) {
    StartSheet(member: Member(zweefId: 3, firstName: "Ellen", lastName: "Peeters")) {} onDismiss: {}
}

#Preview("iPhone · French") {
    StartSheet(member: Member(zweefId: 3, firstName: "Ellen", lastName: "Peeters")) {} onDismiss: {}
        .environment(\.locale, Locale(identifier: "fr"))
}
