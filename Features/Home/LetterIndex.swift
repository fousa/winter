import SwiftUI

/// The A–Z strip on the trailing edge, as in Contacts.
///
/// Only the letters that actually have members, so nobody drags past fifteen
/// empty letters to reach the one they want.
struct LetterIndex: View {
    let letters: [String]
    var onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Button {
                    onSelect(letter)
                } label: {
                    Text(verbatim: letter)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.supporting)
                        .frame(width: 22, height: 16)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Jump to a letter"))
    }
}

/// The undo offer after a start.
///
/// Starting shows no confirmation card, so this is where a start under the
/// wrong name is taken back: small, out of the way, and gone by itself after
/// ten seconds (`docs/spec.md`).
struct UndoChip: View {
    let undo: HomeModel.PendingUndo
    var onUndo: () -> Void
    var onExpire: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward")
                .accessibilityHidden(true)

            Text("\(undo.memberName) started")
                .font(.subheadline)

            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: LayoutMetrics.minimumTapTarget)
        .glassEffect(.regular, in: .capsule)
        .task(id: undo.id) {
            let remaining = undo.expiresAt.timeIntervalSinceNow
            guard remaining > 0 else { return onExpire() }
            try? await Task.sleep(for: .seconds(remaining))
            onExpire()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
