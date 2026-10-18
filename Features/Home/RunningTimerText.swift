import SwiftUI

/// A timer that counts up while a session runs.
///
/// Driven by `TimelineView` rather than a `Timer` of its own: SwiftUI pauses it
/// when the view is off screen, which on a device that sits on a wall all day
/// is the difference between a battery that lasts and one that does not.
/// Monospaced digits so the number does not jitter as it ticks.
struct RunningTimerText: View {
    let start: Date
    var size: CGFloat
    var weight: Font.Weight = .semibold

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(text(at: context.date))
                .font(.system(size: size, weight: weight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.runningTimer)
                .contentTransition(.numericText())
                .accessibilityLabel(accessibilityText(at: context.date))
        }
    }

    private func text(at now: Date) -> String {
        let minutes = SessionRules.duration(start: start, stop: now)
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }

    private func accessibilityText(at now: Date) -> String {
        let minutes = SessionRules.duration(start: start, stop: now)
        return HoursFormatter.durationText(minutes: minutes, locale: .current)
    }
}
