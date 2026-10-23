import SwiftUI

/// The sizes the screens are built from, in one place and resolved from the
/// size classes.
///
/// The numbers come from the mockups, which are an iPad in landscape: those are
/// the regular-width values. Compact width gets its own set rather than scaling
/// the iPad numbers down, because a phone needs bigger relative touch targets
/// and less chrome, not a smaller copy (ADR 0009).
///
/// Nothing here looks at the device model or the screen size, which is the
/// whole point: a layout that keys off `userInterfaceIdiom` is wrong the moment
/// the window is resized.
struct LayoutMetrics: Equatable, Sendable {
    /// Smallest comfortable tap target. Never go below this.
    static let minimumTapTarget: CGFloat = 44

    /// Side padding of a screen's content.
    var gutter: CGFloat
    /// Space between sections.
    var sectionSpacing: CGFloat
    /// Narrowest a member tile may get before the grid drops a column.
    var tileMinimumWidth: CGFloat
    /// Narrowest a "Working now" tile may get. Wider than a plain tile,
    /// because the name has to stay readable next to nothing but the avatar.
    var workingTileMinimumWidth: CGFloat
    var tileHeight: CGFloat
    var tileCornerRadius: CGFloat
    /// Avatar on a member tile.
    var avatarSize: CGFloat
    var cardCornerRadius: CGFloat
    /// Height of a primary action button ("Start", "Stop and save").
    var primaryButtonHeight: CGFloat
    /// The running time on a "Working now" tile.
    var timerFontSize: CGFloat
    /// The big timer on the stop sheet.
    var displayTimerFontSize: CGFloat

    static let regular = LayoutMetrics(
        gutter: 24,
        sectionSpacing: 28,
        tileMinimumWidth: 200,
        workingTileMinimumWidth: 280,
        tileHeight: 84,
        tileCornerRadius: 24,
        avatarSize: 52,
        cardCornerRadius: 28,
        primaryButtonHeight: 64,
        timerFontSize: 28,
        displayTimerFontSize: 76
    )

    static let compact = LayoutMetrics(
        gutter: 16,
        sectionSpacing: 20,
        tileMinimumWidth: 150,
        workingTileMinimumWidth: 220,
        tileHeight: 76,
        tileCornerRadius: 20,
        avatarSize: 44,
        cardCornerRadius: 22,
        primaryButtonHeight: 56,
        timerFontSize: 22,
        displayTimerFontSize: 56
    )

    /// Compact height squeezes the big numbers, not the touch targets.
    ///
    /// iPhone landscape is the case this exists for: the buttons stay the size
    /// a thumb needs, while a 76 pt timer would simply not fit.
    static func resolve(
        horizontal: UserInterfaceSizeClass?,
        vertical: UserInterfaceSizeClass?
    ) -> LayoutMetrics {
        var metrics = horizontal == .compact ? Self.compact : Self.regular
        if vertical == .compact {
            metrics.displayTimerFontSize = min(metrics.displayTimerFontSize, 44)
            metrics.sectionSpacing = min(metrics.sectionSpacing, 16)
        }
        return metrics
    }
}

private struct LayoutMetricsKey: EnvironmentKey {
    static let defaultValue = LayoutMetrics.regular
}

extension EnvironmentValues {
    /// The sizes for the current size class.
    ///
    /// Put in the environment so a view deep in the tree does not have to
    /// re-derive it, and so previews can pin it.
    var metrics: LayoutMetrics {
        get { self[LayoutMetricsKey.self] }
        set { self[LayoutMetricsKey.self] = newValue }
    }
}

extension View {
    /// Resolves ``LayoutMetrics`` for the current size classes and puts it in
    /// the environment. Applied once, at the root.
    func resolvedLayoutMetrics() -> some View {
        modifier(ResolvedLayoutMetrics())
    }
}

private struct ResolvedLayoutMetrics: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontal
    @Environment(\.verticalSizeClass) private var vertical

    func body(content: Content) -> some View {
        content.environment(
            \.metrics,
            LayoutMetrics.resolve(horizontal: horizontal, vertical: vertical)
        )
    }
}
