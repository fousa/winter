import Foundation

/// Answers requests from a handler the test installs, so no test touches the
/// network.
///
/// Handlers are keyed per session, not stored in one global: Swift Testing runs
/// tests in parallel, and a single shared handler means one test answering
/// another test's request — which looks exactly like a decoding bug and wastes
/// an afternoon.
///
/// `@unchecked Sendable` with a lock because `URLProtocol` is handed work on the
/// loading system's own threads, which no concurrency annotation can describe.
/// All mutable state sits behind one mutex.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    /// Returns the status, headers and body for a request — or throws, to
    /// simulate a connection that never arrives.
    typealias Handler = @Sendable (URLRequest) throws -> (Int, [String: String], Data)

    /// Identifies which test a request belongs to.
    static let sessionHeader = "X-Winter-Stub"

    private static let lock = NSLock()
    private nonisolated(unsafe) static var handlers: [String: Handler] = [:]
    private nonisolated(unsafe) static var recorded: [String: [URLRequest]] = [:]

    /// A session wired to its own handler, plus the requests it saw.
    struct Stub {
        let session: URLSession
        fileprivate let id: String

        /// Every request this session made, in order.
        var requests: [URLRequest] {
            StubURLProtocol.lock.withLock { StubURLProtocol.recorded[id] ?? [] }
        }
    }

    static func stub(_ handler: @escaping Handler) -> Stub {
        let id = UUID().uuidString
        lock.withLock {
            handlers[id] = handler
            recorded[id] = []
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [sessionHeader: id]

        return Stub(session: URLSession(configuration: configuration), id: id)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.sessionHeader) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let handler = Self.lock.withLock { () -> Handler? in
            Self.recorded[id, default: []].append(request)
            return Self.handlers[id]
        }

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let (status, headers, body) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// The request body, wherever `URLProtocol` happens to have put it.
    ///
    /// A request that went through `URLSession` carries its body as a stream,
    /// not as `httpBody`, which is a trap worth hiding behind one accessor.
    var capturedBody: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
