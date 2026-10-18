import SwiftUI

/// A member's photo, or their initials when there is no photo.
///
/// In practice this is always the initials: zweef.app's `accounts.json` carries
/// no photo, avatar or image field for any member, verified against a real club
/// (`docs/zweef-api.md`). The file-based branch stays because the model keeps
/// the photo fields for the day zweef.app adds them — and because reading from
/// disk rather than the network is the only way a member list can look like
/// itself in a hangar with no signal.
struct MemberAvatar: View {
    let member: Member
    var size: CGFloat

    var body: some View {
        Group {
            if let image = cachedImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Circle()
            .fill(Color.avatarBackground(forMemberId: member.zweefId).gradient)
            .overlay {
                Text(initialsText)
                    // Deliberately *not* scaled: the circle has a fixed size,
                    // so growing the letters inside it only clips them. The
                    // name is read from the tile, which does scale.
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
            }
    }

    private var initialsText: String {
        let first = member.firstName.first.map(String.init) ?? ""
        let last = member.lastName.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    private var cachedImage: Image? {
        guard let fileName = member.photoFileName,
              let url = PhotoLocation.url(forFileName: fileName),
              let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data)
        else { return nil }
        return Image(uiImage: uiImage)
    }
}

/// Where cached member photos live.
///
/// Application Support rather than Caches: the system may empty Caches when
/// space runs low, and a club on a bad connection would then have a member
/// list of initials for days.
enum PhotoLocation {
    static func url(forFileName fileName: String) -> URL? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        return support.appending(path: "Photos", directoryHint: .isDirectory)
            .appending(path: fileName)
    }
}

#Preview("Initials") {
    HStack(spacing: 16) {
        MemberAvatar(member: Member(zweefId: 1, firstName: "Jan", lastName: "Verhoeven"), size: 52)
        MemberAvatar(member: Member(zweefId: 2, firstName: "Ellen", lastName: "Peeters"), size: 52)
        MemberAvatar(member: Member(zweefId: 3, firstName: "Pieter", lastName: "De Smet"), size: 40)
    }
    .padding()
}
