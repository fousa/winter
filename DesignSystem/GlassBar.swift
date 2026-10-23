import SwiftUI

/// The floating glass container that sits above the content.
///
/// Liquid Glass belongs to the control layer only: this bar, the toolbar,
/// sheets and buttons. Content underneath it — member tiles, lists, cards —
/// stays opaque, so the hours stay readable in a bright hangar (ADR 0006).
struct GlassBar<Content: View>: View {
    @Environment(\.metrics) private var metrics

    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(metrics.gutter * 0.7)
            .glassEffect(.regular, in: .rect(cornerRadius: metrics.cardCornerRadius))
            .padding(.horizontal, metrics.gutter)
    }
}

/// A card that floats above dimmed content, used by the confirmations.
struct GlassCard<Content: View>: View {
    @Environment(\.metrics) private var metrics

    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(metrics.gutter * 1.5)
            .glassEffect(.regular, in: .rect(cornerRadius: 48))
    }
}

/// A small, opaque statistic card: "8 sessions today".
///
/// Content, not control, so no glass here.
struct StatCard: View {
    @Environment(\.metrics) private var metrics

    let title: String
    let value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.supporting)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit()
                // A long duration shrinks a little before it wraps.
                .minimumScaleFactor(0.75)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.supporting)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(metrics.gutter * 0.7)
        .background(Color.card, in: .rect(cornerRadius: metrics.cardCornerRadius))
        // One stop in VoiceOver: "sessions today, 8" rather than two separate
        // fragments a listener has to reassemble.
        .accessibilityElement(children: .combine)
    }
}

#Preview("Stat cards") {
    HStack {
        StatCard(title: "Sessions today", value: "8")
        StatCard(title: "Total", value: "14 h 20 min", detail: "2 also from earlier days")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .resolvedLayoutMetrics()
}
