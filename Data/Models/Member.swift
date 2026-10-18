import Foundation
import SwiftData

/// A club member, mirrored from zweef.app `accounts.json`.
///
/// The app never creates members itself: the club's membership lives in
/// zweef.app and is copied in on every refresh, so there is nothing to keep in
/// sync in the other direction. `zweefId` is the identity, which is what makes
/// a refresh an upsert rather than a duplicate.
@Model
final class Member {
    #Unique<Member>([\.zweefId])

    var zweefId: Int
    var firstName: String
    var lastName: String
    /// Inactive members stay in the database so that their past sessions keep a
    /// name, but they are not offered in the member list.
    var isActive: Bool
    var photoURL: URL?
    /// File name inside Application Support/Photos; the cached photo has to
    /// survive without a network, so the bytes live on disk and only the name
    /// is stored here.
    var photoFileName: String?
    var lastSeenAt: Date?
    var updatedAt: Date

    init(
        zweefId: Int,
        firstName: String,
        lastName: String,
        isActive: Bool = true,
        photoURL: URL? = nil,
        photoFileName: String? = nil,
        lastSeenAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.zweefId = zweefId
        self.firstName = firstName
        self.lastName = lastName
        self.isActive = isActive
        self.photoURL = photoURL
        self.photoFileName = photoFileName
        self.lastSeenAt = lastSeenAt
        self.updatedAt = updatedAt
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
