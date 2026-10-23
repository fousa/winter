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
/// deliberately opaque white (ADR 0006). In dark mode the text colours are the
/// system colours as they are: darkened, they sank into the black, and the
/// plain dark-mode green and orange already read on it.
extension ShapeStyle where Self == Color {
    /// A running timer. 4.9:1 on white.
    ///
    /// Used at 22 pt and up, where 3:1 would be enough, and also for small
    /// icons and a "Connected" label at footnote size — so it is held to the
    /// stricter number and one value serves everywhere.
    static var runningTimer: Color { .darkenedInLightMode(.systemGreen, by: 0.35) }

    /// A flag that the board should notice, never an error. 4.9:1 on white.
    static var flag: Color { .darkenedInLightMode(.systemOrange, by: 0.35) }

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

    /// The fill of a card or tile on a grouped background.
    ///
    /// Not `.background`: in dark mode that is the same black as the grouped
    /// page behind it, and the cards on the sync, close-day and setup screens
    /// vanished. The system's secondary grouped colour is white on grey in
    /// light mode and dark grey on black in dark mode, as the HIG asks.
    static var card: Color { Color(.secondarySystemGroupedBackground) }

    /// A stable colour per member, for the initials placeholder.
    ///
    /// Derived from the zweef.app id rather than the name, so a member keeps
    /// their colour when they marry and their surname changes, and so two
    /// people named Jan do not collide. These carry white initials, so they are
    /// chosen for contrast against white rather than against the card.
    static func avatarBackground(forMemberId id: Int) -> Color {
        let palette: [Color] = [.blue, .indigo, .purple, .teal, .cyan, .mint, .orange, .pink]
        // From the id itself, not `id.hashValue`: Swift seeds hashes afresh
        // on every launch, which gave a member a new colour each time the app
        // started. Euclidean remainder, so a negative id cannot index out of
        // range.
        let index = ((id % palette.count) + palette.count) % palette.count
        return palette[index].mix(with: .black, by: 0.2)
    }
}

private extension Color {
    /// A system colour darkened by `fraction` in light mode, and left as it is
    /// in dark mode.
    ///
    /// Resolved per trait collection, so it also follows Increase Contrast,
    /// which the system colours already adapt to.
    static func darkenedInLightMode(_ base: UIColor, by fraction: CGFloat) -> Color {
        Color(UIColor { traits in
            let resolved = base.resolvedColor(with: traits)
            guard traits.userInterfaceStyle != .dark else { return resolved }
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let keep = 1 - fraction
            return UIColor(red: red * keep, green: green * keep, blue: blue * keep, alpha: alpha)
        })
    }
}
