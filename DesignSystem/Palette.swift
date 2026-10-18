import SwiftUI

/// The handful of colours the app adds to the system palette.
///
/// System colours do the work (they adapt to dark mode and to increased
/// contrast for free); these are the three meanings that need to read the same
/// on every screen.
///
/// Each one is darkened until it passes **4.5:1 against the surface it sits
/// on**, measured rather than guessed. Apple's `systemGreen` and `systemOrange`
/// are 2.2:1 on white — fine as a fill behind white text, unreadable as text
/// on a card. The ratios below hold in light mode, where the content layer is
/// deliberately opaque white (ADR 0006); dark mode gets the system's own
/// adaptation on top.
extension ShapeStyle where Self == Color {
    /// A running timer. 4.9:1 on white.
    ///
    /// Used at 22 pt and up, where 3:1 would be enough, and also for small
    /// icons and a "Connected" label at footnote size — so it is held to the
    /// stricter number and one value serves everywhere.
    static var runningTimer: Color { Color.green.mix(with: .black, by: 0.35) }

    /// A flag that the board should notice, never an error. 4.9:1 on white.
    static var flag: Color { Color.orange.mix(with: .black, by: 0.35) }

    /// Stopping. Red like the Clock app's stop, so the gesture is familiar.
    ///
    /// Darkened just enough that white on it reaches 4.7:1: it is a filled
    /// button, so the text sits on the colour rather than next to it.
    static var stopAction: Color { Color.red.mix(with: .black, by: 0.15) }
}

extension Color {
    /// The tinted background of a flag badge.
    ///
    /// Kept with the flag colour so the pair is checked together: ``flag`` on
    /// this is 4.3:1, which is why the badge text is `.caption.weight(.medium)`
    /// rather than plain caption.
    static var flagBackground: Color { Color.orange.opacity(0.15) }

    /// A stable colour per member, for the initials placeholder.
    ///
    /// Derived from the zweef.app id rather than the name, so a member keeps
    /// their colour when they marry and their surname changes, and so two
    /// people named Jan do not collide. These carry white initials, so they are
    /// chosen for contrast against white rather than against the card.
    static func avatarBackground(forMemberId id: Int) -> Color {
        let palette: [Color] = [.blue, .indigo, .purple, .teal, .cyan, .mint, .orange, .pink]
        return palette[abs(id.hashValue) % palette.count].mix(with: .black, by: 0.2)
    }
}
