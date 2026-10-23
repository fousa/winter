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

    private func session(
        from start: Date,
        to stop: Date?,
        autoStopped: Bool = false,
        stoppedByOther: Bool = false,
        comment: String? = nil
    ) -> WorkSession {
        WorkSession(
            id: sessionId,
            memberId: 101,
            start: start,
            stop: stop,
            status: stop == nil ? .running : .completed,
            autoStopped: autoStopped,
            stoppedByOther: stoppedByOther,
            comment: comment
        )
    }

    private func draft(
        for session: WorkSession,
        taskLabel: String? = "Zweefvliegtuig",
        materialId: Int? = 1
    ) -> MaintenanceHourDraft? {
        MaintenanceHourDraft(
            session: session,
            memberId: 101,
            memberName: "Jan Verhoeven",
            taskLabel: taskLabel,
            materialId: materialId,
            periodId: 1,
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
        // The task is in `project` and the aircraft in `materialId`; the
        // description is the times (ADR 0019).
        #expect(draft.description == "09:12–11:30")
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
        let draft = try #require(self.draft(for: work, taskLabel: nil, materialId: nil))

        #expect(draft.project == "")
        #expect(draft.materialId == nil)
        #expect(draft.description == "09:12–10:12")
    }

    @Test("The member's comment goes after the times; flags stay on the device")
    func includesTheComment() throws {
        let work = session(from: date(15, 14), to: date(15, 21), autoStopped: true, comment: "Lier nagekeken")
        let draft = try #require(self.draft(for: work, taskLabel: "Lier", materialId: 4))

        #expect(draft.description == "14:00–21:00 · Lier nagekeken")
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

    @Test("A registration zweef.app already holds is recognised by what it says")
    func recognisesItsOwnRegistration() throws {
        let work = session(from: date(15, 9), to: date(15, 10), comment: "Banden opgepompt")
        let draft = try #require(self.draft(for: work))
        func hour(userId: Int = 101, date: String = "2026-10-15", hours: Double = 1.0, description: String) -> ZweefMaintenanceHour {
            ZweefMaintenanceHour(id: 9, periodId: 1, userId: userId, date: date, hours: hours, materialId: 1, status: "in_aanvraag", description: description)
        }

        #expect(draft.isSameRegistration(as: hour(description: "09:00–10:00 · Banden opgepompt")))
        // Anyone else's, another day, or other times are not this one.
        #expect(!draft.isSameRegistration(as: hour(userId: 102, description: "09:00–10:00 · Banden opgepompt")))
        #expect(!draft.isSameRegistration(as: hour(date: "2026-10-16", description: "09:00–10:00 · Banden opgepompt")))
        #expect(!draft.isSameRegistration(as: hour(description: "10:00–11:00 · Banden opgepompt")))
    }
}

@Suite("Fake zweef.app API")
struct FakeZweefAPITests {
    @Test("It answers with sample data, so previews and tests need no network")
    func answersFromMemory() async throws {
        let api = FakeZweefAPI()

        #expect(try await api.accounts(inactiveOnly: false).count == 4)
        #expect(try await api.material().count == 4)
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
