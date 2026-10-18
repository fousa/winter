import Foundation
import Security

/// Where the app keeps the things that must never be in the repository, in a
/// backup, or on another device.
///
/// A protocol because the Keychain needs a signed app with an entitlement to
/// work at all, and the rules around these secrets deserve tests that run
/// anywhere.
protocol SecretStore: Sendable {
    func secret(for key: SecretKey) -> String?
    func setSecret(_ value: String?, for key: SecretKey) throws
    func removeAll() throws
}

/// The two secrets this app has, named once.
enum SecretKey: String, CaseIterable, Sendable {
    /// The club's zweef.app API key.
    ///
    /// It opens the club's whole API, which is why the setup and the settings
    /// screen warn about it and why it never leaves the Keychain
    /// ([ADR 0013](../docs/decisions/0013-no-proxy.md)).
    case apiKey
    /// Salt and hash of the admin code, never the code itself.
    case adminCode
}

extension SecretStore {
    /// Whether a secret is set, without reading it.
    ///
    /// Lets the settings screen show "••••••• (set)" without the value ever
    /// reaching a view.
    func hasSecret(for key: SecretKey) -> Bool {
        secret(for: key)?.isEmpty == false
    }
}

/// The real thing: iOS Keychain, this device only.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` on purpose:
/// *AfterFirstUnlock* because a wall-mounted device reboots and has to sync
/// again before anyone touches it, and *ThisDeviceOnly* so the key cannot
/// travel to another device in a backup. With no proxy in front of it, this is
/// the main protection the app can offer the key (SECURITY.md).
struct KeychainSecretStore: SecretStore {
    /// Namespaced per bundle id, so a debug build and a release build on the
    /// same device do not fight over one key.
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "app.winter") {
        self.service = service
    }

    func secret(for key: SecretKey) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    func setSecret(_ value: String?, for key: SecretKey) throws {
        guard let value, !value.isEmpty else {
            let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw SecretStoreError.keychain(status)
            }
            return
        }

        let data = Data(value.utf8)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(for: key) as CFDictionary, update as CFDictionary)

        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = baseQuery(for: key)
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else { throw SecretStoreError.keychain(insertStatus) }
        default:
            throw SecretStoreError.keychain(status)
        }
    }

    /// Wipes every secret, for "Erase everything on this device".
    func removeAll() throws {
        for key in SecretKey.allCases {
            try setSecret(nil, for: key)
        }
    }

    private func baseQuery(for key: SecretKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}

enum SecretStoreError: Error, Equatable {
    case keychain(OSStatus)
}

/// For tests and previews. Never used by the app.
final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [SecretKey: String] = [:]

    init(_ initial: [SecretKey: String] = [:]) {
        values = initial
    }

    func secret(for key: SecretKey) -> String? {
        lock.withLock { values[key] }
    }

    func setSecret(_ value: String?, for key: SecretKey) throws {
        lock.withLock {
            if let value, !value.isEmpty { values[key] = value } else { values[key] = nil }
        }
    }

    func removeAll() throws {
        lock.withLock { values = [:] }
    }
}
