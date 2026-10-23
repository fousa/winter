import Testing
import UIKit

@testable import Winter

/// On the main actor: `ClubLogo` is a view, so its image work belongs there,
/// and running it on a test thread crashed the test host.
@Suite("Club logo")
@MainActor
struct ClubLogoTests {
    private func picture(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                UIColor.systemBlue.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
            .jpegData(compressionQuality: 0.9)!
    }

    @Test("A large photo is scaled down to 512 px on its longest side, keeping its shape")
    func scalesDown() throws {
        let prepared = try #require(ClubLogo.prepare(picture(width: 3000, height: 2000)))
        let image = try #require(UIImage(data: prepared))
        #expect(image.size.width == 512)
        #expect(image.size.height == 341)
    }

    @Test("A small logo is not blown up")
    func keepsSmallImages() throws {
        let prepared = try #require(ClubLogo.prepare(picture(width: 200, height: 100)))
        let image = try #require(UIImage(data: prepared))
        #expect(image.size == CGSize(width: 200, height: 100))
    }

    @Test("Something that is not a picture is refused")
    func refusesNonImages() {
        #expect(ClubLogo.prepare(Data("not a picture".utf8)) == nil)
    }
}
