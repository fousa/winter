import PhotosUI
import SwiftUI
import UIKit

/// The club's logo, round, wherever the app shows it.
///
/// Fitted, never cropped: club logos are often round badges already, and
/// filling the circle cut their edge off. Optional everywhere: a club that
/// never picks one sees no empty circle, the view simply draws nothing.
struct ClubLogo: View {
    let data: Data?
    var size: CGFloat

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(.circle)
                .accessibilityLabel(Text("Club logo"))
        }
    }

    /// Scales a picked picture down to at most `maximum` pixels on its longest
    /// side and encodes it as PNG.
    ///
    /// A photo straight from the camera roll is several megabytes; the logo is
    /// shown at 44 pt at most, so 512 px is plenty even at 3×. PNG rather than
    /// JPEG because logos are usually flat colour, and often transparent.
    static func prepare(_ data: Data, maximum: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maximum / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.pngData()
    }
}

/// Picks, shows and removes the club's logo; shared by the setup assistant and
/// the settings screen so both work the same way.
struct ClubLogoPicker: View {
    @Binding var data: Data?

    @State private var item: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 12) {
            if data != nil {
                ClubLogo(data: data, size: 44)
            } else {
                Image(systemName: "photo.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            Text("Logo")

            Spacer()

            PhotosPicker(selection: $item, matching: .images) {
                Text(data == nil ? "Choose" : "Change")
            }

            if data != nil {
                Button("Remove", role: .destructive) {
                    data = nil
                    item = nil
                }
                .buttonStyle(.borderless)
            }
        }
        .task(id: item) {
            guard let item,
                  let picked = try? await item.loadTransferable(type: Data.self),
                  let prepared = ClubLogo.prepare(picked)
            else { return }
            data = prepared
        }
    }
}
