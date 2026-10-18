import Foundation

extension MaintenanceHourDraft {
    /// The default `category`.
    ///
    /// Empty, not "Maintenance". The documentation's example sends
    /// "Maintenance", but every registration in a real club carries an empty
    /// category, and matching what a club already has is what keeps the board's
    /// own filters working.
    static let defaultCategory = ""

    /// Everything arrives pending, and is approved in zweef.app (ADR 0004).
    static let defaultStatus = "in_aanvraag"

    /// Turns a finished session into the registration that gets uploaded.
    ///
    /// The one place this mapping lives, so the sync engine has no say in what
    /// a registration looks like. A session that is still running cannot be
    /// mapped — `nil` rather than a guess, because uploading an unfinished hour
    /// would put a wrong number in front of the board.
    ///
    /// - Parameters:
    ///   - flagLabel: Resolves flags in the club's *reporting* language, not the
    ///     language of whoever tapped Stop (ADR 0010).
    ///   - calendar: Decides which day the hours land on; the device's own time
    ///     zone defines the club's day.
    init?(
        session: WorkSession,
        memberId: Int,
        memberName: String,
        taskLabel: String?,
        aircraftName: String?,
        materialId: Int?,
        periodId: Int,
        flagLabel: (SessionFlag) -> String,
        calendar: Calendar = .club,
        category: String = MaintenanceHourDraft.defaultCategory,
        subCategory: String = "",
        status: String = MaintenanceHourDraft.defaultStatus
    ) {
        guard let stop = session.stop, let minutes = session.minutes else { return nil }

        self.init(
            periodId: periodId,
            userId: memberId,
            userName: memberName,
            date: Self.dateString(for: session.start, calendar: calendar),
            hours: HoursFormatter.decimalHours(minutes: minutes),
            materialId: materialId,
            workorderId: nil,
            isPrivate: false,
            category: category,
            subCategory: subCategory,
            project: taskLabel ?? "",
            description: RegistrationDescription.text(
                for: RegistrationDescription.Input(
                    sessionId: session.id,
                    start: session.start,
                    stop: stop,
                    taskLabel: taskLabel,
                    aircraftName: aircraftName,
                    flags: session.flags
                ),
                flagLabel: flagLabel,
                timeZone: calendar.timeZone
            ),
            status: status
        )
    }

    /// `yyyy-MM-dd`, fixed format and POSIX locale: this is a key in somebody
    /// else's database, not something anyone reads.
    private static func dateString(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
