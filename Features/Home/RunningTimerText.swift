import SwiftUI

/// A timer that counts up while a session runs.
///
/// Driven by `TimelineView` rather than a `Timer` of its own: SwiftUI pauses it
/// when the view is off screen, which on a device that sits on a wall all day
/// is the difference between a battery that lasts and one that does not.
/// Monospaced digits so the number does not jitter as it ticks.
struct RunningTimerText: View {
    /// How the elapsed time is written.
    enum Style {
        /// "1:05" — the large clock on the stop sheet.
        case clock
        /// "1h05m", or "46m" under an hour — compact inside a member tile.
        case hoursMinutes
    }

    let start: Date
    var size: CGFloat
    var weight: Font.Weight = .semibold
    var style: Style = .clock
    /// Green on the stop sheet, where the clock is the subject; a member tile
    /// passes `.primary`, because the time is information there, not a signal.
    var color: Color = .runningTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(text(at: context.date))
                .scaledFont(size: size, relativeTo: .title, weight: weight, design: .rounded, maximum: size * 1.4)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .accessibilityLabel(accessibilityText(at: context.date))
        }
    }

    private func text(at now: Date) -> String {
        let minutes = SessionRules.duration(start: start, stop: now)
        switch style {
        case .clock: return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
        case .hoursMinutes: return HoursFormatter.compactDuration(minutes: minutes)
        }
    }

    private func accessibilityText(at now: Date) -> String {
        let minutes = SessionRules.duration(start: start, stop: now)
        return HoursFormatter.durationText(minutes: minutes, locale: .current)
    }
}
