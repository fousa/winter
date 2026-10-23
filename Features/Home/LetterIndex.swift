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
/// Starting shows no confirmation card, so this is both the confirmation and
/// the way to take back a start under the wrong name: a green check, "Jan is
/// working since 14:05" in large type and an "Undo" button, gone by itself
/// after ten seconds (`docs/spec.md`). Large on purpose: an iPad cannot buzz,
/// so this is the only sign an older member gets that the tap landed.
struct UndoChip: View {
    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let undo: HomeModel.PendingUndo
    var onUndo: () -> Void
    var onExpire: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.runningTimer)
                .accessibilityHidden(true)

            // A size up on an iPad, read from a step back; a phone's width
            // is already filled by the headline.
            Text(message)
                .font(horizontalSizeClass == .compact ? .headline : .title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Button("Undo", systemImage: "arrow.uturn.backward", action: onUndo)
                .buttonStyle(.glass)
                .accessibilityHint(Text("Removes this timer again"))
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .frame(minHeight: horizontalSizeClass == .compact ? 60 : 68)
        .glassEffect(.regular, in: .capsule)
        // On an iPad there is no buzz to feel, so this is the only sign the
        // tap landed: say it out loud too, for VoiceOver.
        .onAppear {
            AccessibilityNotification.Announcement(message).post()
        }
        .task(id: undo.id) {
            let remaining = undo.expiresAt.timeIntervalSinceNow
            guard remaining > 0 else { return onExpire() }
            try? await Task.sleep(for: .seconds(remaining))
            onExpire()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// "Jan is working since 14:05": who, and that the clock runs, rather
    /// than the bare "Jan started" that was easy to miss.
    private var message: String {
        let time = undo.startedAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        return String(localized: "\(undo.memberName) is working since \(time)")
    }
}
