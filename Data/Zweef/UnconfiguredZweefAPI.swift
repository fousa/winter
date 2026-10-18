import Foundation

/// The API of a device that has not been set up yet.
///
/// Every call fails with ``ZweefError/invalidConfiguration``, which the sync
/// screen turns into "this device has no connection configured". A null object
/// rather than an optional API, so the sync engine has one less branch and
/// cannot forget it: the hours still record and still queue, they just have
/// nowhere to go yet (ADR 0001).
struct UnconfiguredZweefAPI: ZweefAPI {
    func club() async throws -> ZweefClub { throw ZweefError.invalidConfiguration }

    func accounts(inactiveOnly: Bool) async throws -> [ZweefAccount] {
        throw ZweefError.invalidConfiguration
    }

    func material() async throws -> [ZweefMaterial] { throw ZweefError.invalidConfiguration }

    func currentPeriodHours() async throws -> [ZweefMaintenanceHour] {
        throw ZweefError.invalidConfiguration
    }

    func activePeriodId() async throws -> Int? { throw ZweefError.invalidConfiguration }

    func create(_ draft: MaintenanceHourDraft) async throws -> CreatedRegistration {
        throw ZweefError.invalidConfiguration
    }
}
