import SwiftUI

/// The time worked so far, counting up while a session runs and standing
/// still while it is paused.
///
/// Driven by `TimelineView` rather than a `Timer` of its own: SwiftUI pauses it
/// when the view is off screen, which on a device that sits on a wall all day
/// is the difference between a battery that lasts and one that does not.
/// Monospaced digits so the number does not jitter as it ticks.
///
/// It takes the session's facts rather than a start time, because the time
/// worked is not "now minus start" any more: breaks are taken out, and a
/// paused timer shows where it stopped (ADR 0022).
struct RunningTimerText: View {
    let facts: SessionFacts
    var size: CGFloat
    var weight: Font.Weight = .semibold

    var body: some View {
        if facts.pausedAt != nil || facts.stop != nil {
            // Nothing to tick: no timeline, so a paused tile costs nothing.
            label(minutes: SessionRules.workedMinutes(of: facts, now: .now))
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                label(minutes: SessionRules.workedMinutes(of: facts, now: context.date))
            }
        }
    }

    /// "46m" or "1h05m", the one way the app writes a duration that is still
    /// running or just finished.
    private func label(minutes: Minutes) -> some View {
        Text(HoursFormatter.compactDuration(minutes: minutes))
            .scaledFont(size: size, relativeTo: .title, weight: weight, design: .rounded, maximum: size * 1.4)
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .contentTransition(.numericText())
            .accessibilityLabel(HoursFormatter.durationText(minutes: minutes, locale: .current))
    }
}
