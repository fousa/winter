import Foundation

/// The task list a club starts with.
///
/// Seeded once during setup in the language the setup runs in, and editable
/// afterwards: from that moment the labels are club data and are shown as the
/// club typed them, never translated (ADR 0010). The keys stay stable so a
/// renamed task keeps its icon, its colour and its history.
enum DefaultTasks {
    /// The six entries from the mockups, in display order.
    static func seed(locale: Locale = .current) -> [TaskDefinition] {
        [
            task(key: "glider", label: "task.glider", symbol: "airplane", color: "blue", order: 0, asksForAircraft: true, locale: locale),
            task(key: "winch", label: "task.winch", symbol: "arrow.up.and.down.and.arrow.left.and.right", color: "orange", order: 1, locale: locale),
            task(key: "workshop", label: "task.workshop", symbol: "wrench.and.screwdriver", color: "purple", order: 2, locale: locale),
            task(key: "grounds", label: "task.grounds", symbol: "leaf", color: "green", order: 3, locale: locale),
            task(key: "clubhouse", label: "task.clubhouse", symbol: "house", color: "teal", order: 4, locale: locale),
            task(key: "other", label: "task.other", symbol: "ellipsis", color: "gray", order: 5, locale: locale),
        ]
    }

    private static func task(
        key: String,
        label: String.LocalizationValue,
        symbol: String,
        color: String,
        order: Int,
        asksForAircraft: Bool = false,
        locale: Locale
    ) -> TaskDefinition {
        TaskDefinition(
            key: key,
            label: String(localized: LocalizedStringResource(label, locale: locale)),
            symbolName: symbol,
            colorName: color,
            sortOrder: order,
            asksForAircraft: asksForAircraft
        )
    }
}
