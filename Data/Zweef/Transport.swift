import Foundation

/// One call to zweef.app, described without saying how it gets there.
struct Endpoint: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
    }

    var method: Method = .get
    /// Path under the club's API root, e.g. `/accounts.json`.
    var path: String
    var query: [String: String] = [:]
    var body: Data?
}

/// Builds the requests the app sends to zweef.app.
///
/// The app talks to zweef.app directly, with the club's API key from the
/// Keychain ([ADR 0013](../../docs/decisions/0013-no-proxy.md)). There is no
/// proxy and no second mode, so this is one concrete type rather than a
/// protocol with implementations — indirection that only ever has one answer
/// is harder to read, not more flexible.
struct ZweefTransport: Sendable {
    static let host = URL(string: "https://admin.gliding.app")!

    /// The club's schema name, from its zweef.app settings. Part of the URL.
    let clubSchema: String
    /// From the Keychain. Never logged, never shown, never in the repository.
    let apiKey: String

    var baseURL: URL {
        Self.host
            .appending(path: "club")
            .appending(path: clubSchema)
            .appending(path: "api")
    }

    /// The request for an endpoint, with the key attached.
    ///
    /// A short timeout on purpose: on a flaky club connection, failing quickly
    /// and retrying later beats a request that hangs while someone waits.
    func request(for endpoint: Endpoint) throws -> URLRequest {
        let path = endpoint.path.hasPrefix("/") ? String(endpoint.path.dropFirst()) : endpoint.path

        guard var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw ZweefError.invalidConfiguration
        }

        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else { throw ZweefError.invalidConfiguration }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
