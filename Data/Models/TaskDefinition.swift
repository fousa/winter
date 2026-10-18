import Foundation
import SwiftData

/// One entry in the club's task list ("what were you working on?").
///
/// Stored rather than hard-coded because every club words these differently,
/// and because the label is club data: once a club edits it, it is shown as
/// typed and never translated (ADR 0010). `key` stays stable so a renamed task
/// keeps its icon and its history.
@Model
final class TaskDefinition {
    #Unique<TaskDefinition>([\.key])

    private(set) var key: String
    var label: String
    var symbolName: String
    var colorName: String
    var sortOrder: Int
    /// Tasks like glider maintenance ask which aircraft; "grounds" does not.
    var asksForAircraft: Bool
    /// Archived instead of deleted, so past sessions keep their task.
    var isArchived: Bool

    init(
        key: String,
        label: String,
        symbolName: String,
        colorName: String,
        sortOrder: Int,
        asksForAircraft: Bool = false,
        isArchived: Bool = false
    ) {
        self.key = key
        self.label = label
        self.symbolName = symbolName
        self.colorName = colorName
        self.sortOrder = sortOrder
        self.asksForAircraft = asksForAircraft
        self.isArchived = isArchived
    }
}
