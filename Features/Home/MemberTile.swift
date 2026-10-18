import SwiftUI

/// One member in the grid: tap it to start.
///
/// Opaque white on the grouped background, because this is content rather than
/// control. The whole tile is the button — on a shared device with dirty hands,
/// a small target inside a tile is a missed tap.
struct MemberTile: View {
    @Environment(\.metrics) private var metrics

    let member: Member
    /// Set while this member is working, so the list and the bar agree.
    var isWorking: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
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

                Spacer(minLength: 0)

                if isWorking {
                    Image(systemName: "stopwatch")
                        .foregroundStyle(.runningTimer)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: metrics.tileHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: metrics.tileCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isWorking
                ? Text("\(member.fullName), working now")
                : Text(member.fullName)
        )
        .accessibilityHint(isWorking ? Text("Opens stopping") : Text("Starts your hours"))
    }
}

#Preview {
    let member = Member(zweefId: 1, firstName: "Jan", lastName: "Verhoeven")
    return VStack {
        MemberTile(member: member, isWorking: false) {}
        MemberTile(member: member, isWorking: true) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .resolvedLayoutMetrics()
}
