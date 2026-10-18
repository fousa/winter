import SwiftUI
import UIKit

extension View {
    /// Keeps the screen on while something is being timed.
    ///
    /// A member walks away from the device while the timer runs; if the screen
    /// locks, the next person cannot see who is working and starts a second
    /// session. Only held while it is true, and released on disappear, so a
    /// phone in a pocket is not kept awake for nothing.
    ///
    /// The shared-device-only distinction arrives with the configuration in
    /// phase 4b; until then a running timer is the condition on both.
    func keepScreenAwake(_ isAwake: Bool) -> some View {
        modifier(KeepScreenAwake(isAwake: isAwake))
    }
}

private struct KeepScreenAwake: ViewModifier {
    let isAwake: Bool

    func body(content: Content) -> some View {
        content
            .onAppear { apply(isAwake) }
            .onChange(of: isAwake) { _, newValue in apply(newValue) }
            .onDisappear { apply(false) }
    }

    private func apply(_ isAwake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = isAwake
    }
}
