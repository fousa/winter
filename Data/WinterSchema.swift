import Foundation
import SwiftData

/// The one place that lists what is stored, so the app and the tests cannot
/// drift apart on it.
enum WinterSchema {
    static let models: [any PersistentModel.Type] = [
        Member.self,
        Aircraft.self,
        WorkSession.self,
        TaskDefinition.self,
        AppSettings.self,
        SyncLog.self,
    ]

    /// The container the app runs on.
    ///
    /// No CloudKit and no shared store: every device keeps its own sessions and
    /// uploads them itself (ADR 0009).
    static func container() throws -> ModelContainer {
        try ModelContainer(for: Schema(models))
    }

    /// An in-memory container for tests and previews, so neither ever touches
    /// the real database.
    static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

extension Calendar {
    /// The calendar that defines "the day" for a club.
    ///
    /// The device's own time zone, not a fixed one: the shared device sits at
    /// the club, and the app has to work for any club on zweef.app (ADR 0008).
    /// It decides when the closing time falls and which day an hour is
    /// uploaded under.
    static var club: Calendar {
        Calendar.autoupdatingCurrent
    }
}
