import Foundation

/// The non-secret settings that belong to this device rather than to the club.
///
/// UserDefaults, not SwiftData: these describe the device's connection, they
/// are read before the database is opened, and they are not club data. The
/// secrets that go with them live in a ``SecretStore``; the club's own settings
/// live in `AppSettings` (`docs/configuration.md`).
@MainActor
@Observable
final class AppConfiguration {
    private let defaults: UserDefaults
    private let managed: ManagedConfiguration

    init(defaults: UserDefaults = .standard, managed: ManagedConfiguration = ManagedConfiguration()) {
        self.defaults = defaults
        self.managed = managed
    }

    // MARK: - Connection

    /// The club's schema name in zweef.app, which is part of the API's URL.
    var clubSchema: String {
        get { managed.clubSchema ?? defaults.string(forKey: Key.clubSchema) ?? "" }
        set { defaults.set(newValue.trimmed, forKey: Key.clubSchema) }
    }

    /// What goes in `category` on a registration.
    ///
    /// Empty by default, because that is what every registration in a real club
    /// carries — the documentation's "Maintenance" does not match reality
    /// (`docs/zweef-api.md`).
    var category: String {
        get { defaults.string(forKey: Key.category) ?? MaintenanceHourDraft.defaultCategory }
        set { defaults.set(newValue, forKey: Key.category) }
    }

    /// What goes in `status`. Registrations arrive pending approval (ADR 0004).
    var status: String {
        get { defaults.string(forKey: Key.status) ?? MaintenanceHourDraft.defaultStatus }
        set { defaults.set(newValue, forKey: Key.status) }
    }

    /// Which fields the club's MDM has fixed, so the settings screen can show
    /// them greyed out instead of letting someone edit a value that will be
    /// overwritten.
    var managedKeys: Set<ManagedConfiguration.Field> { managed.presentFields }

    // MARK: - Admin code attempts

    /// How many times the admin code has been entered wrongly in a row.
    ///
    /// Persisted rather than kept in memory: force-quitting the app must not be
    /// a way to reset the delay.
    var failedAdminAttempts: Int {
        get { defaults.integer(forKey: Key.failedAdminAttempts) }
        set { defaults.set(newValue, forKey: Key.failedAdminAttempts) }
    }

    var adminLockedUntil: Date? {
        get { defaults.object(forKey: Key.adminLockedUntil) as? Date }
        set { defaults.set(newValue, forKey: Key.adminLockedUntil) }
    }

    // MARK: - Completeness

    /// Whether the device can talk to zweef.app at all.
    ///
    /// The setup assistant stays on screen until this is true, because without
    /// it the app could record hours it can never deliver — and nobody would
    /// find out until the board asked where they were.
    func isConnectionConfigured(secrets: some SecretStore) -> Bool {
        !clubSchema.trimmed.isEmpty && secrets.hasSecret(for: .apiKey)
    }

    /// Whether setup has been completed, connection and admin code both.
    func isComplete(secrets: some SecretStore) -> Bool {
        isConnectionConfigured(secrets: secrets) && secrets.hasSecret(for: .adminCode)
    }

    /// For "Erase everything on this device".
    func reset() {
        for key in Key.all { defaults.removeObject(forKey: key) }
    }

    private enum Key {
        static let clubSchema = "clubSchema"
        static let category = "zweefCategory"
        static let status = "zweefStatus"
        static let failedAdminAttempts = "failedAdminAttempts"
        static let adminLockedUntil = "adminLockedUntil"

        static let all = [
            clubSchema, category, status, failedAdminAttempts, adminLockedUntil,
        ]
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
