import SwiftUI

/// A member's photo, or their initials when there is no photo.
///
/// Photos come from zweef.app and are cached on disk, so this reads from a file
/// rather than the network: in a hangar without a connection the member list
/// still has to look like itself. Until the photo cache exists (phase 4) every
/// member falls back to initials, which is also what happens for members who
/// never uploaded one.
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
