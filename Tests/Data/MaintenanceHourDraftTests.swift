import Foundation
import Testing

@testable import Winter

@Suite("Registration mapping")
struct MaintenanceHourDraftTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return calendar
    }()

    private let sessionId = UUID(uuidString: "A1B2C3D4-0000-0000-0000-000000000000")!

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func label(_ flag: SessionFlag) -> String {
        switch flag {
        case .shortSession: "korte sessie"
        case .longSession: "lange sessie"
        case .stoppedAutomatically: "automatisch gestopt"
        case .stoppedBySomeoneElse: "gestopt door iemand anders"
        }
    }

    private func session(
        from start: Date,
        to stop: Date?,
        autoStopped: Bool = false,
        stoppedByOther: Bool = false
    ) -> WorkSession {
        WorkSession(
            id: sessionId,
            memberId: 101,
            start: start,
            stop: stop,
            status: stop == nil ? .running : .completed,
            autoStopped: autoStopped,
            stoppedByOther: stoppedByOther
        )
    }

    private func draft(
        for session: WorkSession,
        taskLabel: String? = "Zweefvliegtuig",
        aircraftName: String? = "ASK 21",
        materialId: Int? = 1
    ) -> MaintenanceHourDraft? {
        MaintenanceHourDraft(
            session: session,
            memberId: 101,
            memberName: "Jan Verhoeven",
            taskLabel: taskLabel,
            aircraftName: aircraftName,
            materialId: materialId,
            periodId: 1,
            flagLabel: label,
            calendar: calendar
        )
    }

    @Test("A finished session becomes the registration the board will read")
    func mapsAFinishedSession() throws {
        let work = session(from: date(15, 9, 12), to: date(15, 11, 30))
        let draft = try #require(self.draft(for: work))

        #expect(draft.periodId == 1)
        #expect(draft.userId == 101)
        #expect(draft.userName == "Jan Verhoeven")
        #expect(draft.date == "2026-10-15")
        #expect(draft.hours == 2.3)
        #expect(draft.materialId == 1)
        #expect(draft.workorderId == nil)
        #expect(draft.isPrivate == false)
        #expect(draft.project == "Zweefvliegtuig")
        #expect(draft.status == "in_aanvraag")
        #expect(draft.description == "Zweefvliegtuig · ASK 21 · 09:12–11:30 [ou:a1b2c3d4]")
    }

    @Test("Category is empty, matching what a real club already has")
    func categoryIsEmptyByDefault() throws {
        let work = session(from: date(15, 9), to: date(15, 10))
        let draft = try #require(self.draft(for: work))

        #expect(draft.category == "")
        #expect(draft.subCategory == "")
    }

    @Test("A running session cannot be uploaded")
    func refusesARunningSession() {
        let work = session(from: date(15, 9, 12), to: nil)
        #expect(draft(for: work) == nil)
    }

    @Test("Without a task there is no project, and the times still carry it")
    func mapsWithoutATask() throws {
        let work = session(from: date(15, 9, 12), to: date(15, 10, 12))
        let draft = try #require(self.draft(for: work, taskLabel: nil, aircraftName: nil, materialId: nil))

        #expect(draft.project == "")
        #expect(draft.materialId == nil)
        #expect(draft.description == "09:12–10:12 [ou:a1b2c3d4]")
    }

    @Test("Flags travel along in the club's reporting language")
    func includesFlagsInTheReportingLanguage() throws {
        let work = session(from: date(15, 14), to: date(15, 21), autoStopped: true)
        let draft = try #require(self.draft(for: work, taskLabel: "Lier", aircraftName: nil, materialId: 4))

        #expect(draft.description == "Lier · 14:00–21:00 · automatisch gestopt [ou:a1b2c3d4]")
        #expect(draft.hours == 7.0)
    }

    @Test("A session that runs past midnight is logged on the day it started")
    func usesTheStartingDay() throws {
        let work = session(from: date(15, 23, 30), to: date(16, 0, 30))
        let draft = try #require(self.draft(for: work))

        #expect(draft.date == "2026-10-15")
        #expect(draft.hours == 1.0)
        #expect(draft.description.contains("23:30–00:30"))
    }

    @Test("Minutes become hours with two decimals, as zweef.app expects")
    func convertsMinutesToDecimalHours() throws {
        let work = session(from: date(15, 9), to: date(15, 9, 20))
        let draft = try #require(self.draft(for: work))
        #expect(draft.hours == 0.33)
    }

    @Test("The dedup tag is in the description, so a timed-out upload is recognised")
    func carriesTheDedupTag() throws {
        let work = session(from: date(15, 9), to: date(15, 10))
        let draft = try #require(self.draft(for: work))

        #expect(RegistrationDescription.describes(sessionId: sessionId, description: draft.description))
    }
}

@Suite("Fake zweef.app API")
struct FakeZweefAPITests {
    @Test("It answers with sample data, so previews and tests need no network")
    func answersFromMemory() async throws {
        let api = FakeZweefAPI()

        #expect(try await api.accounts(inactiveOnly: false).count == 4)
        #expect(try await api.material().count == 3)
        #expect(try await api.activePeriodId() == 1)
        #expect(try await api.club().name == "Gliding Club Example")
        #expect(await api.callLog == ["accounts", "material", "hours", "club"])
    }

    @Test("It can be told to fail a few times, then work — the retry case")
    func failsThenSucceeds() async throws {
        let api = FakeZweefAPI()
        await api.failNextCreates(2)

        await #expect(throws: ZweefError.unreachable) { try await api.create(FakeDraft.minimal) }
        await #expect(throws: ZweefError.unreachable) { try await api.create(FakeDraft.minimal) }
        let created = try await api.create(FakeDraft.minimal)

        #expect(created.id == 1)
        #expect(await api.createdDrafts.count == 1)
    }

    @Test("It can refuse a registration the way zweef.app does")
    func canReject() async throws {
        let api = FakeZweefAPI()
        await api.setCreate(.failure(.rejected(status: 422, reason: "Period closed")))

        await #expect(throws: ZweefError.rejected(status: 422, reason: "Period closed")) {
            try await api.create(FakeDraft.minimal)
        }
        #expect(await api.createdDrafts.isEmpty)
    }
}
