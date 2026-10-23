import XCTest

/// Not a test: turns the simulator to landscape for
/// `scripts/app-store-screenshots.sh`.
///
/// Xcode 27 has no Simulator app whose menu could rotate a device, `simctl`
/// cannot, and iPadOS 26 refuses an app's own request to rotate in its
/// windowing mode. `XCUIDevice` still can, and the simulator stays turned
/// after the run, so the script's later launches open in landscape.
final class RotateDevice: XCTestCase {
    @MainActor
    func testLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    @MainActor
    func testPortrait() {
        XCUIDevice.shared.orientation = .portrait
    }
}
