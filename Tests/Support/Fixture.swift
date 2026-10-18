import Foundation

/// Loads a file from `Tests/Fixtures`.
///
/// Found through `#filePath` rather than a bundle, so the same code works when
/// the tests run from Xcode and from the command line, without a resource
/// phase to keep in step.
enum Fixture {
    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }

    static func url(_ name: String) -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()   // Support/
            .deletingLastPathComponent()   // Tests/
            .appending(path: "Fixtures")
            .appending(path: name)
    }
}
