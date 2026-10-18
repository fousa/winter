import SwiftUI

extension View {
    /// A font at a specific size that still grows with Dynamic Type.
    ///
    /// `.font(.system(size:))` is fixed: a member who has set Larger Text gets
    /// the same 28 pt timer as everyone else, which is exactly backwards —
    /// the running timer is the number they came to read. This scales the size
    /// against a text style and stops at `maximum`, because past a point a
    /// bigger timer only pushes the member's name off the card.
    ///
    /// Use the plain `.font(.title)` tokens wherever a size is not prescribed
    /// by the design; this is for the few places where the mockups give a
    /// number.
    func scaledFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        maximum: CGFloat? = nil
    ) -> some View {
        modifier(ScaledFont(
            size: size,
            textStyle: textStyle,
            weight: weight,
            design: design,
            maximum: maximum ?? size * 1.6
        ))
    }
}

private struct ScaledFont: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat

    private let weight: Font.Weight
    private let design: Font.Design
    private let maximum: CGFloat

    init(
        size: CGFloat,
        textStyle: Font.TextStyle,
        weight: Font.Weight,
        design: Font.Design,
        maximum: CGFloat
    ) {
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
        self.maximum = maximum
    }

    func body(content: Content) -> some View {
        content.font(.system(size: min(scaledSize, maximum), weight: weight, design: design))
    }
}
