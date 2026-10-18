import CryptoKit
import Foundation

/// Checks the six digits that protect the settings screen.
///
/// The code protects *settings*, not use: starting and stopping hours needs
/// nothing (ADR 0002). So this guards tokens and the "erase everything" button
/// against a curious member, not against an attacker with the device in a lab —
/// six digits cannot do that, and pretending otherwise would be worse than
/// saying so.
///
/// The code itself is never stored. A random salt and a SHA-256 hash go in the
/// Keychain, and wrong attempts cost increasing amounts of time.
@MainActor
struct AdminCodeVerifier {
    enum Failure: Error, Equatable {
        /// Wrong code, with how long before the next attempt is allowed.
        case incorrect(lockedFor: TimeInterval)
        /// Still waiting out an earlier mistake.
        case lockedOut(remaining: TimeInterval)
        /// Six digits, nothing else.
        case malformed
        case storage
    }

    /// Six digits: short enough to be remembered by a committee, long enough
    /// that guessing it costs more patience than the lockout allows.
    static let length = 6

    /// Wrong attempts before the delay starts. Three is room for a typo.
    static let freeAttempts = 3

    private let secrets: any SecretStore
    private let configuration: AppConfiguration
    private let now: () -> Date

    init(secrets: any SecretStore, configuration: AppConfiguration, now: @escaping () -> Date = Date.init) {
        self.secrets = secrets
        self.configuration = configuration
        self.now = now
    }

    var isConfigured: Bool {
        secrets.hasSecret(for: .adminCode)
    }

    /// How long to wait after `failures` wrong attempts.
    ///
    /// Nothing for the first three, then 30 s doubling to five minutes. Slow
    /// enough to make guessing pointless, short enough that the one person who
    /// legitimately forgot is not locked out of their own clubhouse all evening.
    static func lockoutDuration(afterFailures failures: Int) -> TimeInterval {
        guard failures > freeAttempts else { return 0 }
        let step = failures - freeAttempts
        return min(30 * pow(2, Double(step - 1)), 300)
    }

    /// Stores a new code. Also clears any lockout: whoever can set the code is
    /// not the person being kept out.
    func setCode(_ code: String) throws {
        guard Self.isWellFormed(code) else { throw Failure.malformed }

        var salt = Data(count: 16)
        let result = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 16, bytes.baseAddress!)
        }
        guard result == errSecSuccess else { throw Failure.storage }

        let stored = "\(salt.base64EncodedString()):\(Self.hash(code: code, salt: salt))"
        do {
            try secrets.setSecret(stored, for: .adminCode)
        } catch {
            throw Failure.storage
        }
        configuration.failedAdminAttempts = 0
        configuration.adminLockedUntil = nil
    }

    /// Checks a code, counting the attempt.
    ///
    /// Throws rather than returning a result, so a caller cannot forget to look
    /// at the answer — the one thing a lock must never allow.
    func verify(_ code: String) throws {
        if let until = configuration.adminLockedUntil, until > now() {
            throw Failure.lockedOut(remaining: until.timeIntervalSince(now()))
        }

        guard let stored = secrets.secret(for: .adminCode) else { throw Failure.storage }
        let parts = stored.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let salt = Data(base64Encoded: parts[0]) else { throw Failure.storage }

        guard Self.hash(code: code, salt: salt) == parts[1] else {
            configuration.failedAdminAttempts += 1
            let lockout = Self.lockoutDuration(afterFailures: configuration.failedAdminAttempts)
            configuration.adminLockedUntil = lockout > 0 ? now().addingTimeInterval(lockout) : nil
            throw Failure.incorrect(lockedFor: lockout)
        }

        configuration.failedAdminAttempts = 0
        configuration.adminLockedUntil = nil
    }

    static func isWellFormed(_ code: String) -> Bool {
        code.count == length && code.allSatisfy(\.isNumber)
    }

    /// Salted SHA-256. Not a password hash — six digits do not deserve the
    /// battery cost of one, and the threat model is a curious member, not an
    /// offline attack on a stolen hash.
    private static func hash(code: String, salt: Data) -> String {
        var input = salt
        input.append(Data(code.utf8))
        return Data(SHA256.hash(data: input)).base64EncodedString()
    }
}
