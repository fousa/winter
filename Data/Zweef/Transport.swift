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

/// Turns an ``Endpoint`` into a request that will be accepted.
///
/// Two implementations, because a club either runs the proxy (recommended) or
/// talks to zweef.app directly (ADR 0003). ``ZweefClient`` does not know which:
/// that way the choice is a configuration detail and not a branch in every
/// call.
protocol Transport: Sendable {
    func request(for endpoint: Endpoint) throws -> URLRequest
}

/// Through the club's own Cloudflare Worker, which holds the API key.
///
/// The device sends only its own revocable token, so a stolen device is
/// disarmed by removing that token from the proxy — no new API key, no
/// reconfiguring the other devices (ADR 0009).
struct ProxyTransport: Transport {
    /// e.g. `https://winter-proxy.<account>.workers.dev`
    let baseURL: URL
    /// From the Keychain. Never logged.
    let deviceToken: String

    func request(for endpoint: Endpoint) throws -> URLRequest {
        var request = try URLRequest.winter(baseURL: baseURL, endpoint: endpoint)
        request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        return request
    }
}

/// Straight to zweef.app with the club's API key on the device.
///
/// zweef.app's own documentation says not to keep the key client-side, so this
/// exists for clubs without anyone to run a worker, and the settings screen
/// warns about it.
struct DirectTransport: Transport {
    static let host = URL(string: "https://admin.gliding.app")!

    /// The club's schema name, from its zweef.app settings.
    let clubSchema: String
    /// From the Keychain. Never logged.
    let apiKey: String

    var baseURL: URL {
        Self.host
            .appending(path: "club")
            .appending(path: clubSchema)
            .appending(path: "api")
    }

    func request(for endpoint: Endpoint) throws -> URLRequest {
        var request = try URLRequest.winter(baseURL: baseURL, endpoint: endpoint)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        return request
    }
}

extension URLRequest {
    /// The parts both transports share.
    ///
    /// A short timeout on purpose: on a flaky club connection, failing quickly
    /// and retrying later beats a request that hangs while someone waits.
    static func winter(baseURL: URL, endpoint: Endpoint) throws -> URLRequest {
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
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
