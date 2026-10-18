import Foundation

/// Everything the app asks of zweef.app.
///
/// A protocol so the sync engine can be tested against ``FakeZweefAPI`` with no
/// network at all — which is the only way to test the cases that matter
/// (timeouts, a 4xx on one registration, two triggers at once).
///
/// Deliberately small: six calls, all of them read-only except the one that
/// creates a registration. Nothing here can change a member, a flight or a
/// ledger, even though the API key could.
protocol ZweefAPI: Sendable {
    /// The club's own details. May well fail: see ``ZweefClub``.
    func club() async throws -> ZweefClub

    /// Active members, or only the inactive ones.
    ///
    /// - Parameter inactiveOnly: `?inactive=1` returns *only* inactive members,
    ///   not all of them, so getting everybody means asking twice.
    func accounts(inactiveOnly: Bool) async throws -> [ZweefAccount]

    /// Aircraft and equipment.
    func material() async throws -> [ZweefMaterial]

    /// The registrations in the current maintenance period.
    func currentPeriodHours() async throws -> [ZweefMaintenanceHour]

    /// The id of the period new registrations belong to.
    func activePeriodId() async throws -> Int?

    /// Creates one registration, pending the board's approval.
    func create(_ draft: MaintenanceHourDraft) async throws -> CreatedRegistration
}
