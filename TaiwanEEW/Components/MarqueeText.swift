//
//  MarqueeText.swift
//  TaiwanEEW
//
//  Single-line text that scrolls back and forth when it does not fit, and sits perfectly
//  still when it does.
//
//  Written for the epicenter name in the alert header. A CLGeocoder placemark is several
//  times longer in English than in Chinese — 花蓮縣 against "Hualien County, Taiwan" — and
//  truncating it is the one thing that must not happen there: the tail of a place name is
//  often the part that identifies it.
//

import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font

    /// Points per second. Slow enough to read, and slow enough not to pull the eye away
    /// from a countdown that is running next to it.
    var speed: CGFloat = 24
    /// Held still at each end, so the beginning and the end are both readable without
    /// waiting for a pass.
    var pause: TimeInterval = 1.4

    /// Indefinite motion is exactly what Reduce Motion exists to switch off, and this sits
    /// on a screen someone is reading during an earthquake. Honoured rather than overridden:
    /// the fallback scales the text down and truncates, which is what it did before.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    /// How far past the right edge the text runs. Zero means it fits and nothing moves.
    private var overflow: CGFloat { max(0, textWidth - containerWidth) }
    private var scrolls: Bool { overflow > 0.5 && !reduceMotion }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContainerWidthKey.self, value: proxy.size.width)
                }
            )
            .onPreferenceChange(ContainerWidthKey.self) { width in
                guard abs(width - containerWidth) > 0.5 else { return }
                containerWidth = width
                restart()
            }
            .onPreferenceChange(TextWidthKey.self) { width in
                guard abs(width - textWidth) > 0.5 else { return }
                textWidth = width
                restart()
            }
            .onChange(of: text) { _ in restart() }
            .onChange(of: reduceMotion) { _ in restart() }
    }

    @ViewBuilder
    private var content: some View {
        if scrolls {
            measuredText
                .offset(x: offset)
        } else {
            // Fits, or motion is off. minimumScaleFactor keeps the previous behaviour of
            // shrinking a little before giving up and truncating.
            measuredText
                .minimumScaleFactor(0.75)
        }
    }

    /// The one Text both branches use, so the width measured is the width drawn.
    ///
    /// `fixedSize` is what lets it exceed the container at all — without it the frame below
    /// would compress it and there would be nothing to scroll.
    private var measuredText: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: scrolls, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: TextWidthKey.self, value: proxy.size.width)
                }
            )
    }

    private func restart() {
        offset = 0
        guard scrolls else { return }
        let distance = overflow
        let duration = Double(distance / speed)
        // autoreverses gives the return pass; the delay is the pause at the start, and the
        // matching pause at the far end comes free because the reverse leg has the same
        // delay applied to it.
        withAnimation(.linear(duration: duration).delay(pause).repeatForever(autoreverses: true)) {
            offset = -distance
        }
    }
}

private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
