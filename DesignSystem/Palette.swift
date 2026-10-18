import SwiftUI

/// The handful of colours the app adds to the system palette.
///
/// System colours do the work (they adapt to dark mode and to increased
/// contrast for free); these are the three meanings that need to read the same
/// on every screen.
extension ShapeStyle where Self == Color {
    /// A running timer. A darkened green, because plain `.green` on white does
    /// not reach a comfortable contrast ratio at small sizes.
    static var runningTimer: Color { Color.green.mix(with: .black, by: 0.3) }

    /// A flag that the board should notice, never an error.
    static var flag: Color { .orange }

    /// Stopping. Red like the Clock app's stop, so the gesture is familiar.
    static var stopAction: Color { .red }
}

extension Color {
    /// A stable colour per member, for the initials placeholder.
    ///
    /// Derived from the zweef.app id rather than the name, so a member keeps
    /// their colour when they marry and their surname changes, and so two
    /// people named Jan do not collide.
    static func avatarBackground(forMemberId id: Int) -> Color {
        let palette: [Color] = [.blue, .indigo, .purple, .teal, .cyan, .mint, .orange, .pink]
        return palette[abs(id.hashValue) % palette.count]
    }
}
