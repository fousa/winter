import SwiftUI

/// Starting or leaving the sample club (ADR 0021), handed down the view tree
/// like SwiftUI's own `DismissAction`.
///
/// A type rather than a bare closure so the environment can compare it:
/// equal by what it does, which never changes for a given value.
struct DemoAction: Equatable {
    enum Kind { case start, leave }

    let kind: Kind
    fileprivate let perform: @MainActor () -> Void

    init(_ kind: Kind, perform: @escaping @MainActor () -> Void) {
        self.kind = kind
        self.perform = perform
    }

    @MainActor func callAsFunction() { perform() }

    static func == (lhs: DemoAction, rhs: DemoAction) -> Bool { lhs.kind == rhs.kind }
}

extension EnvironmentValues {
    /// Set while the real setup can show, so the setup assistant can offer
    /// the sample club.
    @Entry var startDemo: DemoAction?

    /// Set only while the demo runs, which is also how the home screen knows
    /// it is one.
    @Entry var leaveDemo: DemoAction?
}
