import Foundation
import Testing

@testable import Winter

@MainActor
@Suite("App configuration")
struct AppConfigurationTests {
    /// Its own defaults suite per test, so tests cannot read each other's
    /// settings or the developer's.
    private func makeConfiguration(
        managed: [String: Any] = [:]
    ) -> (AppConfiguration, UserDefaults) {
        let suite = "winter.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (AppConfiguration(defaults: defaults, managed: ManagedConfiguration(values: managed)), defaults)
    }

    @Test("A fresh device defaults to the proxy, which is the recommended mode")
    func defaultsToProxy() {
        let (configuration, _) = makeConfiguration()
        #expect(configuration.connectionMode == .proxy)
        #expect(configuration.proxyURL.isEmpty)
    }

    @Test("Values survive a round trip, trimmed")
    func storesValues() {
        let (configuration, _) = makeConfiguration()
        configuration.proxyURL = "  https://winter-proxy.example.workers.dev  "
        configuration.clubSchema = " exampleclub "

        #expect(configuration.proxyURL == "https://winter-proxy.example.workers.dev")
        #expect(configuration.clubSchema == "exampleclub")
    }

    @Test("The zweef.app category defaults to empty, matching a real club")
    func categoryDefaultsToEmpty() {
        let (configuration, _) = makeConfiguration()
        #expect(configuration.category == "")
        #expect(configuration.status == "in_aanvraag")
    }

    @Test("A proxy device is configured once it has a URL and a token")
    func proxyCompleteness() {
        let (configuration, _) = makeConfiguration()
        let secrets = InMemorySecretStore()

        #expect(!configuration.isConnectionConfigured(secrets: secrets))

        configuration.proxyURL = "https://winter-proxy.example.workers.dev"
        #expect(!configuration.isConnectionConfigured(secrets: secrets))

        try? secrets.setSecret("token", for: .deviceToken)
        #expect(configuration.isConnectionConfigured(secrets: secrets))

        // Setup is not finished until the settings are protected too.
        #expect(!configuration.isComplete(secrets: secrets))
        try? secrets.setSecret("salt:hash", for: .adminCode)
        #expect(configuration.isComplete(secrets: secrets))
    }

    @Test("A direct device needs a schema and a key, not a proxy URL")
    func directCompleteness() {
        let (configuration, _) = makeConfiguration()
        let secrets = InMemorySecretStore()
        configuration.connectionMode = .direct
        configuration.clubSchema = "exampleclub"

        #expect(!configuration.isConnectionConfigured(secrets: secrets))
        try? secrets.setSecret("key", for: .apiKey)
        #expect(configuration.isConnectionConfigured(secrets: secrets))
    }

    @Test("A proxy URL that is not a URL does not count as configured")
    func rejectsRubbishProxyURL() {
        let (configuration, _) = makeConfiguration()
        let secrets = InMemorySecretStore([.deviceToken: "token"])
        configuration.proxyURL = "not a url at all"
        #expect(!configuration.isConnectionConfigured(secrets: secrets))
    }

    @Test("MDM values win over anything stored on the device")
    func managedValuesWin() {
        let (configuration, _) = makeConfiguration(managed: [
            "connectionMode": "direct",
            "proxyURL": "https://managed.example.workers.dev",
            "clubSchema": "managedclub",
        ])
        configuration.connectionMode = .proxy
        configuration.clubSchema = "typedclub"

        #expect(configuration.connectionMode == .direct)
        #expect(configuration.proxyURL == "https://managed.example.workers.dev")
        #expect(configuration.clubSchema == "managedclub")
        #expect(configuration.managedKeys.contains(.clubSchema))
    }

    @Test("Erasing clears every stored value")
    func resetClearsEverything() {
        let (configuration, _) = makeConfiguration()
        configuration.proxyURL = "https://winter-proxy.example.workers.dev"
        configuration.failedAdminAttempts = 4

        configuration.reset()

        #expect(configuration.proxyURL.isEmpty)
        #expect(configuration.failedAdminAttempts == 0)
    }
}

@Suite("Managed configuration")
struct ManagedConfigurationTests {
    @Test("An empty dictionary manages nothing")
    func emptyByDefault() {
        let managed = ManagedConfiguration(values: [:])
        #expect(managed.isEmpty)
        #expect(managed.presentFields.isEmpty)
    }

    @Test("A pushed closing time is parsed")
    func parsesClosingTime() {
        let managed = ManagedConfiguration(values: ["closingTime": "18:30"])
        #expect(managed.closingTime == DateComponents(hour: 18, minute: 30))
        #expect(managed.presentFields == [.closingTime])
    }

    @Test("A nonsense closing time is ignored rather than guessed at", arguments: [
        "nine o'clock", "25:00", "18:70", "18", "", "18:30:00",
    ])
    func ignoresMalformedClosingTime(raw: String) {
        #expect(ManagedConfiguration(values: ["closingTime": raw]).closingTime == nil)
    }

    @Test("Blank strings count as absent, so an empty MDM field is not a value")
    func blankValuesAreAbsent() {
        let managed = ManagedConfiguration(values: ["proxyURL": "   ", "deviceToken": ""])
        #expect(managed.proxyURL == nil)
        #expect(managed.deviceToken == nil)
        #expect(managed.isEmpty)
    }
}

@MainActor
@Suite("Admin code")
struct AdminCodeVerifierTests {
    private final class TestClock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeVerifier() -> (AdminCodeVerifier, InMemorySecretStore, AppConfiguration, TestClock) {
        let defaults = UserDefaults(suiteName: "winter.tests.\(UUID().uuidString)")!
        let configuration = AppConfiguration(defaults: defaults)
        let secrets = InMemorySecretStore()
        let clock = TestClock(Date(timeIntervalSince1970: 1_760_000_000))
        let verifier = AdminCodeVerifier(
            secrets: secrets,
            configuration: configuration,
            now: { clock.now }
        )
        return (verifier, secrets, configuration, clock)
    }

    @Test("A device with no code set is not configured")
    func startsUnconfigured() {
        let (verifier, _, _, _) = makeVerifier()
        #expect(!verifier.isConfigured)
    }

    @Test("The right code opens the settings")
    func acceptsTheRightCode() throws {
        let (verifier, _, _, _) = makeVerifier()
        try verifier.setCode("123456")

        #expect(verifier.isConfigured)
        try verifier.verify("123456")
    }

    @Test("The code itself is never stored")
    func storesOnlyASaltedHash() throws {
        let (verifier, secrets, _, _) = makeVerifier()
        try verifier.setCode("123456")

        let stored = try #require(secrets.secret(for: .adminCode))
        #expect(!stored.contains("123456"))
        #expect(stored.contains(":"))
    }

    @Test("Two devices with the same code store different hashes")
    func saltsPerDevice() throws {
        let (first, firstSecrets, _, _) = makeVerifier()
        let (second, secondSecrets, _, _) = makeVerifier()
        try first.setCode("123456")
        try second.setCode("123456")

        #expect(firstSecrets.secret(for: .adminCode) != secondSecrets.secret(for: .adminCode))
    }

    @Test("Anything that is not six digits is refused")
    func requiresSixDigits() throws {
        let (verifier, _, _, _) = makeVerifier()
        #expect(throws: AdminCodeVerifier.Failure.malformed) { try verifier.setCode("12345") }
        #expect(throws: AdminCodeVerifier.Failure.malformed) { try verifier.setCode("1234567") }
        #expect(throws: AdminCodeVerifier.Failure.malformed) { try verifier.setCode("12345a") }
    }

    @Test("A typo costs nothing the first few times")
    func firstMistakesAreFree() throws {
        let (verifier, _, configuration, _) = makeVerifier()
        try verifier.setCode("123456")

        for _ in 0..<3 {
            #expect(throws: AdminCodeVerifier.Failure.incorrect(lockedFor: 0)) {
                try verifier.verify("000000")
            }
        }
        #expect(configuration.adminLockedUntil == nil)
    }

    @Test("Guessing gets slower, and stops at five minutes")
    func lockoutGrows() {
        #expect(AdminCodeVerifier.lockoutDuration(afterFailures: 3) == 0)
        #expect(AdminCodeVerifier.lockoutDuration(afterFailures: 4) == 30)
        #expect(AdminCodeVerifier.lockoutDuration(afterFailures: 5) == 60)
        #expect(AdminCodeVerifier.lockoutDuration(afterFailures: 6) == 120)
        #expect(AdminCodeVerifier.lockoutDuration(afterFailures: 7) == 240)
        #expect(AdminCodeVerifier.lockoutDuration(afterFailures: 50) == 300)
    }

    @Test("While locked out, even the right code waits")
    func lockoutBlocksTheRightCode() throws {
        let (verifier, _, _, clock) = makeVerifier()
        try verifier.setCode("123456")
        for _ in 0..<4 { try? verifier.verify("000000") }

        #expect(throws: AdminCodeVerifier.Failure.lockedOut(remaining: 30)) {
            try verifier.verify("123456")
        }

        // Once it has passed, the right code works again.
        clock.now = clock.now.addingTimeInterval(31)
        try verifier.verify("123456")
    }

    @Test("A success clears the count, so one bad evening is not permanent")
    func successResetsTheCount() throws {
        let (verifier, _, configuration, _) = makeVerifier()
        try verifier.setCode("123456")
        try? verifier.verify("000000")
        try verifier.verify("123456")

        #expect(configuration.failedAdminAttempts == 0)
        #expect(configuration.adminLockedUntil == nil)
    }

    @Test("Setting a new code clears a lockout")
    func settingACodeClearsLockout() throws {
        let (verifier, _, configuration, _) = makeVerifier()
        try verifier.setCode("123456")
        for _ in 0..<5 { try? verifier.verify("000000") }
        #expect(configuration.adminLockedUntil != nil)

        try verifier.setCode("654321")

        #expect(configuration.adminLockedUntil == nil)
        try verifier.verify("654321")
    }
}

@Suite("Connection settings")
struct ConnectionSettingsTests {
    @Test("Proxy settings build a proxy transport that sends the device token")
    func buildsProxyTransport() throws {
        let settings = ConnectionSettings(
            mode: .proxy,
            proxyURL: "https://winter-proxy.example.workers.dev",
            clubSchema: "",
            deviceToken: "device-token",
            apiKey: nil
        )

        let transport = try #require(settings.makeTransport() as? ProxyTransport)
        #expect(transport.deviceToken == "device-token")

        let request = try transport.request(for: Endpoint(path: "/material.json"))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer device-token")
    }

    @Test("Direct settings build a direct transport with the club's own API root")
    func buildsDirectTransport() throws {
        let settings = ConnectionSettings(
            mode: .direct,
            proxyURL: "",
            clubSchema: "exampleclub",
            deviceToken: nil,
            apiKey: "api-key"
        )

        let transport = try #require(settings.makeTransport() as? DirectTransport)
        let request = try transport.request(for: Endpoint(path: "/material.json"))
        #expect(request.url?.absoluteString == "https://admin.gliding.app/club/exampleclub/api/material.json")
        #expect(request.value(forHTTPHeaderField: "X-API-KEY") == "api-key")
    }

    @Test("A proxy URL needs a scheme and a host; prose is not a URL", arguments: [
        ("https://winter-proxy.example.workers.dev", true),
        ("http://localhost:8787", true),
        ("not a url at all", false),
        ("winter-proxy.example.workers.dev", false),
        ("", false),
        ("ftp://example.com", false),
        ("https://", false),
    ])
    func validatesProxyURLs(input: (String, Bool)) {
        #expect(ConnectionSettings.isUsableProxyURL(input.0) == input.1)
    }

    @Test("Incomplete settings build nothing rather than something broken", arguments: [
        ConnectionSettings(mode: .proxy, proxyURL: "", clubSchema: "", deviceToken: "t", apiKey: nil),
        ConnectionSettings(mode: .proxy, proxyURL: "https://example.com", clubSchema: "", deviceToken: nil, apiKey: nil),
        ConnectionSettings(mode: .proxy, proxyURL: "nonsense", clubSchema: "", deviceToken: "t", apiKey: nil),
        ConnectionSettings(mode: .direct, proxyURL: "", clubSchema: "", deviceToken: nil, apiKey: "k"),
        ConnectionSettings(mode: .direct, proxyURL: "", clubSchema: "club", deviceToken: nil, apiKey: nil),
    ])
    func refusesIncompleteSettings(settings: ConnectionSettings) {
        #expect(settings.makeTransport() == nil)
    }

    @Test("An unconfigured device gets an API that says so, rather than no API")
    func unconfiguredDeviceGetsTheNullObject() async {
        let provider = ConnectionProvider()

        await #expect(throws: ZweefError.invalidConfiguration) {
            try await provider.api().currentPeriodHours()
        }
    }

    @Test("A token changed in settings is used by the next call")
    func providerPicksUpNewSettings() throws {
        let provider = ConnectionProvider()
        provider.update(ConnectionSettings(
            mode: .proxy,
            proxyURL: "https://winter-proxy.example.workers.dev",
            clubSchema: "",
            deviceToken: "first",
            apiKey: nil
        ))
        #expect(provider.current?.deviceToken == "first")

        provider.update(ConnectionSettings(
            mode: .proxy,
            proxyURL: "https://winter-proxy.example.workers.dev",
            clubSchema: "",
            deviceToken: "second",
            apiKey: nil
        ))
        #expect(provider.current?.deviceToken == "second")
    }

    @Test("Testing a connection reports the period, and survives a broken club.json")
    func connectionTestReportsWhatItFound() async throws {
        let api = FakeZweefAPI(club: .failure(.server(status: 500)))

        let result = try await ConnectionTester.test(api)

        #expect(result.periodId == 1)
        #expect(result.registrationCount == 1)
        // club.json answering 500 is not a failed test (ADR 0012).
        #expect(result.clubName == nil)
    }

    @Test("A refused token makes the test fail, so nobody saves a dead connection")
    func connectionTestFailsOnRefusedToken() async {
        let api = FakeZweefAPI(hours: .failure(.notAuthorised))

        await #expect(throws: ZweefError.notAuthorised) {
            try await ConnectionTester.test(api)
        }
    }
}

@Suite("Secret store")
struct SecretStoreTests {
    @Test("A secret round-trips, and an empty value removes it")
    func roundTrip() throws {
        let store = InMemorySecretStore()
        #expect(!store.hasSecret(for: .deviceToken))

        try store.setSecret("token", for: .deviceToken)
        #expect(store.secret(for: .deviceToken) == "token")
        #expect(store.hasSecret(for: .deviceToken))

        try store.setSecret("", for: .deviceToken)
        #expect(store.secret(for: .deviceToken) == nil)
    }

    @Test("Erasing removes every secret, for a device leaving the club")
    func removeAll() throws {
        let store = InMemorySecretStore([
            .deviceToken: "token",
            .apiKey: "key",
            .adminCode: "salt:hash",
        ])

        try store.removeAll()

        #expect(SecretKey.allCases.allSatisfy { store.secret(for: $0) == nil })
    }
}
