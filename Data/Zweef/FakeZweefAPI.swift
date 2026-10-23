import Foundation

/// A ``ZweefAPI`` that answers from memory, for tests and previews.
///
/// The cases worth testing are the ugly ones — a timeout halfway through, a
/// 4xx on one registration, two sync triggers at once — and none of them can be
/// provoked reliably against a real server. So this one can be told to fail a
/// set number of times, to fail permanently, or to simply work.
///
/// An actor because the sync engine will call it from a background context and
/// the recorded calls must not race.
actor FakeZweefAPI: ZweefAPI {
    /// Every draft that was *accepted*, in order, so a test can assert what
    /// actually landed in zweef.app.
    ///
    /// A rejected or failed upload leaves nothing here, the same way a refused
    /// POST leaves nothing on the server — otherwise a test could not tell the
    /// difference between "sent" and "stored".
    private(set) var createdDrafts: [MaintenanceHourDraft] = []

    /// Names of the calls made, in order.
    private(set) var callLog: [String] = []

    private var clubResult: Result<ZweefClub, ZweefError>
    private var accountsResult: Result<[ZweefAccount], ZweefError>
    private var inactiveAccountsResult: Result<[ZweefAccount], ZweefError>
    private var materialResult: Result<[ZweefMaterial], ZweefError>
    private var hoursResult: Result<[ZweefMaintenanceHour], ZweefError>
    private var createResult: Result<CreatedRegistration, ZweefError>

    /// Fails the next *n* creates with ``ZweefError/unreachable``, then behaves.
    private var failCreateTimes = 0

    init(
        club: Result<ZweefClub, ZweefError> = .success(ZweefClub(name: "Gliding Club Example")),
        accounts: Result<[ZweefAccount], ZweefError> = .success(FakeZweefAPI.sampleAccounts),
        inactiveAccounts: Result<[ZweefAccount], ZweefError> = .success([]),
        material: Result<[ZweefMaterial], ZweefError> = .success(FakeZweefAPI.sampleMaterial),
        hours: Result<[ZweefMaintenanceHour], ZweefError> = .success(FakeZweefAPI.sampleHours),
        create: Result<CreatedRegistration, ZweefError> = .success(CreatedRegistration(id: 1))
    ) {
        self.clubResult = club
        self.accountsResult = accounts
        self.inactiveAccountsResult = inactiveAccounts
        self.materialResult = material
        self.hoursResult = hours
        self.createResult = create
    }

    // MARK: - Arranging

    func setClub(_ result: Result<ZweefClub, ZweefError>) { clubResult = result }
    func setAccounts(_ result: Result<[ZweefAccount], ZweefError>) { accountsResult = result }
    func setMaterial(_ result: Result<[ZweefMaterial], ZweefError>) { materialResult = result }
    func setHours(_ result: Result<[ZweefMaintenanceHour], ZweefError>) { hoursResult = result }
    func setCreate(_ result: Result<CreatedRegistration, ZweefError>) { createResult = result }

    /// Makes the next `times` uploads fail as if the connection dropped.
    func failNextCreates(_ times: Int) { failCreateTimes = times }

    // MARK: - ZweefAPI

    func club() async throws -> ZweefClub {
        callLog.append("club")
        return try clubResult.get()
    }

    func accounts(inactiveOnly: Bool) async throws -> [ZweefAccount] {
        callLog.append(inactiveOnly ? "accounts(inactive)" : "accounts")
        return try (inactiveOnly ? inactiveAccountsResult : accountsResult).get()
    }

    func material() async throws -> [ZweefMaterial] {
        callLog.append("material")
        return try materialResult.get()
    }

    func currentPeriodHours() async throws -> [ZweefMaintenanceHour] {
        callLog.append("hours")
        return try hoursResult.get()
    }

    func activePeriodId() async throws -> Int? {
        try await currentPeriodHours().first?.periodId
    }

    func create(_ draft: MaintenanceHourDraft) async throws -> CreatedRegistration {
        callLog.append("create")
        if failCreateTimes > 0 {
            failCreateTimes -= 1
            throw ZweefError.unreachable
        }
        let created = try createResult.get()
        createdDrafts.append(draft)
        return created
    }

    // MARK: - Sample data

    /// The same fictional members as `SampleData`, so a preview driven by the
    /// fake looks like a preview driven by the store.
    static let sampleAccounts: [ZweefAccount] = [
        ZweefAccount(id: 101, firstName: "Jan", lastName: "Verhoeven", isActive: true),
        ZweefAccount(id: 102, firstName: "Koen", lastName: "Maes", isActive: true),
        ZweefAccount(id: 103, firstName: "Ellen", lastName: "Peeters", isActive: true),
        ZweefAccount(id: 104, firstName: "Sofie", lastName: "Claes", isActive: true),
    ]

    static let sampleMaterial: [ZweefMaterial] = [
        ZweefMaterial(id: 1, name: "ASK 21", type: "Schleicher ASK 21", category: "kist", kistConfiguration: "Glider", kistCategory: "club", status: "in bedrijf", isVisible: true, order: nil),
        ZweefMaterial(id: 2, name: "LS4", type: "Rolladen-Schneider LS4", category: "kist", kistConfiguration: "Glider", kistCategory: "club", status: "in bedrijf", isVisible: true, order: nil),
        ZweefMaterial(id: 3, name: "Discus", type: "Schempp-Hirth Discus b", category: "kist", kistConfiguration: "Glider", kistCategory: "prive", status: "in bedrijf", isVisible: true, order: nil),
        ZweefMaterial(id: 4, name: "Lier", type: "Supacat", category: "rollend", kistConfiguration: nil, kistCategory: nil, status: "in bedrijf", isVisible: true, order: nil),
        ZweefMaterial(id: 5, name: "Club", type: nil, category: "overig", kistConfiguration: nil, kistCategory: nil, status: "in bedrijf", isVisible: true, order: nil),
    ]

    static let sampleHours: [ZweefMaintenanceHour] = [
        ZweefMaintenanceHour(
            id: 11,
            periodId: 1,
            userId: 101,
            date: "2026-09-21",
            hours: 2.0,
            materialId: 1,
            status: "in_aanvraag",
            description: "Glider · ASK 21 · 09:12–11:30 [ou:a1b2c3d4]"
        )
    ]
}
