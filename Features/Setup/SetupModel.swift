import Foundation
import SwiftData
import SwiftUI

/// The state of the setup assistant, and the one place it writes anything.
///
/// Nothing is saved until the step that owns it is left, and the connection is
/// tested before it is stored: a club that mistypes a token should find out
/// standing at the device, not three days later when the board asks where the
/// hours went.
@MainActor
@Observable
final class SetupModel {
    enum Step: Int, CaseIterable, Identifiable {
        case welcome
        case connection
        case club
        case logo
        case adminCode
        case done

        var id: Int { rawValue }
    }

    /// What testing the connection produced, if it has been tried.
    enum TestState: Equatable {
        case untested
        case testing
        case succeeded(ConnectionTestResult)
        case failed(ZweefError)
    }

    var step: Step = .welcome

    // Connection
    var clubSchema: String
    var apiKey = ""
    var testState: TestState = .untested

    // Club
    var clubName = ""
    /// Optional; picked from Photos, already scaled down (``ClubLogo/prepare(_:)``).
    var clubLogo: Data?
    var closingHour: Int
    var requiresComment: Bool
    var closingMinute: Int

    // Admin code
    var adminCode = ""
    var adminCodeRepeat = ""
    var adminCodeError: String?

    private let configuration: AppConfiguration
    private let secrets: any SecretStore
    private let connection: ConnectionProvider
    private let settings: AppSettings
    private let managed: ManagedConfiguration

    init(
        configuration: AppConfiguration,
        secrets: any SecretStore,
        connection: ConnectionProvider,
        settings: AppSettings,
        managed: ManagedConfiguration = ManagedConfiguration()
    ) {
        self.configuration = configuration
        self.secrets = secrets
        self.connection = connection
        self.settings = settings
        self.managed = managed

        // Prefilled from the MDM when a club pushed the schema, so there is
        // less to type on a device mounted on a wall. The key is never pushed.
        self.clubSchema = configuration.clubSchema
        self.clubName = settings.clubName ?? ""
        self.clubLogo = settings.clubLogo
        self.closingHour = settings.closingHour
        self.requiresComment = settings.requiresComment
        self.closingMinute = settings.closingMinute
    }

    // MARK: - Steps

    /// Whether the current step has what it needs to move on.
    var canAdvance: Bool {
        switch step {
        case .welcome, .done:
            return true
        case .connection:
            // Testing is encouraged, not required: a club setting the app up in
            // a hangar with no signal must still be able to finish.
            return hasConnectionFields
        case .club, .logo:
            // The logo is optional: "Next" without one is fine.
            return true
        case .adminCode:
            return AdminCodeVerifier.isWellFormed(adminCode) && adminCode == adminCodeRepeat
        }
    }

    var hasConnectionFields: Bool {
        !clubSchema.trimmed.isEmpty && !apiKey.trimmed.isEmpty
    }

    func isManaged(_ field: ManagedConfiguration.Field) -> Bool {
        managed.presentFields.contains(field)
    }

    func advance() {
        guard canAdvance else { return }

        switch step {
        case .connection: saveConnection()
        case .club: saveClub()
        case .logo: settings.clubLogo = clubLogo
        case .adminCode:
            // Replaces any code an earlier install left in the Keychain,
            // which iOS keeps when an app is deleted.
            guard saveAdminCode() else { return }
        default: break
        }

        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    /// "Start using Winter": the device is set up.
    func finish() {
        configuration.hasCompletedSetup = true
    }

    func goBack() {
        if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
    }

    // MARK: - Connection

    /// Tries the connection as typed, without saving it.
    ///
    /// A success also offers the club's name, which saves typing — when
    /// `club.json` answers at all.
    func testConnection() async {
        testState = .testing

        let snapshot = ConnectionSettings(clubSchema: clubSchema.trimmed, apiKey: apiKey.trimmed)

        guard snapshot.makeTransport() != nil else {
            testState = .failed(.invalidConfiguration)
            return
        }

        do {
            let result = try await ConnectionTester.test(snapshot.makeAPI())
            testState = .succeeded(result)
            if clubName.trimmed.isEmpty, let fetched = result.clubName, !fetched.isEmpty {
                clubName = fetched
            }
        } catch let error as ZweefError {
            testState = .failed(error)
        } catch {
            testState = .failed(.unreachable)
        }
    }

    private func saveConnection() {
        configuration.clubSchema = clubSchema.trimmed

        // The key goes to the Keychain and is dropped from memory: the field is
        // cleared so it does not sit in a view model for the rest of the
        // session.
        try? secrets.setSecret(apiKey.trimmed, for: .apiKey)
        apiKey = ""

        connection.update(ConnectionSettings(configuration: configuration, secrets: secrets))

        if case .succeeded(let result) = testState, let periodId = result.periodId {
            settings.activePeriodId = periodId
        }
    }

    private func saveClub() {
        // A typed name is remembered as typed, so a later refresh does not
        // rename the club behind their back (ADR 0012).
        if let fetched = fetchedClubName, fetched == clubName.trimmed {
            settings.applyFetchedClubName(fetched)
        } else {
            settings.setClubName(typed: clubName)
        }

        settings.requiresComment = requiresComment
        settings.closingHour = closingHour
        settings.closingMinute = closingMinute
    }

    private var fetchedClubName: String? {
        guard case .succeeded(let result) = testState else { return nil }
        return result.clubName
    }


    /// Whether setup has produced a usable device.
    var isComplete: Bool {
        configuration.isComplete(secrets: secrets)
    }

    private func saveAdminCode() -> Bool {
        let verifier = AdminCodeVerifier(secrets: secrets, configuration: configuration)
        do {
            try verifier.setCode(adminCode)
            adminCode = ""
            adminCodeRepeat = ""
            adminCodeError = nil
            return true
        } catch {
            adminCodeError = String(localized: "Could not store the code. Try again.")
            return false
        }
    }
}
