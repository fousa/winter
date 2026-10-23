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
            let minutes = SessionRules.duration(start: start, stop: context.date)
            // "46m" or "1h05m", the one way the app writes a duration that
            // is still running or just finished.
            Text(HoursFormatter.compactDuration(minutes: minutes))
                .scaledFont(size: size, relativeTo: .title, weight: weight, design: .rounded, maximum: size * 1.4)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText())
                .accessibilityLabel(HoursFormatter.durationText(minutes: minutes, locale: .current))
        }
    }
}
