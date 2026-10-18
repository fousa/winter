import SwiftUI

/// The second of the two taps that start an hour.
///
/// It exists for one reason: on a shared device the wrong name gets tapped, and
/// this is where that is caught. So the photo and the name are large, and "That
/// isn't me" is as easy to hit as "Start".
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
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        onStart()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .frame(maxWidth: .infinity, minHeight: metrics.primaryButtonHeight)
                    }
                    .buttonStyle(.glassProminent)

                    Button("That isn't me") {
                        dismiss()
                        onDismiss()
                    }
                    .frame(maxWidth: .infinity, minHeight: LayoutMetrics.minimumTapTarget)
                    .buttonStyle(.glass)

                    Text("You pick what you worked on when you stop.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(metrics.gutter)
            .navigationTitle("Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                        onDismiss()
                    }
                    .labelStyle(.iconOnly)
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
