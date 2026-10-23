import SwiftUI

/// The A–Z strip on the trailing edge, as in Contacts — but large enough to
/// hit.
///
/// Only the letters that actually have members, so nobody drags past fifteen
/// empty letters to reach the one they want. The letters are bold, in the
/// tint colour, on a glass column, so it reads as something to tap; each one
/// is 44 pt wide and as tall as the screen allows, falling back to smaller
/// sizes only when a club has more letters than fit. The old strip had 11 pt
/// letters on 22×16 pt targets, which older members missed or never noticed.
struct LetterIndex: View {
    let letters: [String]
    var onSelect: (String) -> Void

    /// Width the home screen keeps free beside the grid for the index.
    static let width: CGFloat = 52

    var body: some View {
        ViewThatFits(in: .vertical) {
            column(font: .title3.weight(.bold), rowHeight: 40)
            column(font: .headline, rowHeight: 30)
            column(font: .subheadline.weight(.semibold), rowHeight: 22)
        }
        .padding(.trailing, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Jump to a letter"))
    }

    private func column(font: Font, rowHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                Button {
                    onSelect(letter)
                } label: {
                    Text(verbatim: letter)
                        .font(font)
                        .foregroundStyle(.tint)
                        .frame(width: 44, height: rowHeight)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .fixedSize()
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
