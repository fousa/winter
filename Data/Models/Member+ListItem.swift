import Foundation

/// Lets the member-list rules work on the stored model without `Domain`
/// knowing that SwiftData exists.
extension Member: MemberListItem {
    var memberId: Int { zweefId }
}
