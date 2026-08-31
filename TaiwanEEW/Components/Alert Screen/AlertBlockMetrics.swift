//
//  AlertBlockMetrics.swift
//  TaiwanEEW
//
//  How wide the intensity and countdown blocks are, given the space they have.
//
//  They used to be a fixed 170pt square each, with the surrounding margin defined as
//  whatever was left over divided by three. Inside the floating card that left 11pt
//  gutters on a 393pt screen — 340pt of blocks in a 373pt card — so the content ran
//  almost edge to edge and read as cramped. Inverting it makes the margin the fixed
//  quantity and the blocks the flexible one.
//

import SwiftUI

enum AlertBlockMetrics {
    /// Distance from the card's edge to the content.
    static let edgeInset: CGFloat = 18

    /// Between the three blocks — the status bar, the intensity block and the countdown
    /// block. Half the edge inset, so the run of blocks reads as one group set in from the
    /// card rather than three things spaced the same as the card's own margin.
    static var blockGap: CGFloat { edgeInset / 2 }

    /// The size the blocks were before they became flexible. Still the ceiling, so a wide
    /// container gets more margin rather than ever-larger blocks, and still the fallback
    /// for callers with no width to work from — the two previews, mainly.
    static let defaultSize: CGFloat = 170
    /// Floor, so a narrow phone shrinks the blocks rather than the gutters.
    static let minimumSize: CGFloat = 120

    /// - Parameter containerWidth: the card's inner width, measured rather than derived
    ///   from UIScreen — the card is inset from the screen and the two differ, and the
    ///   iPad panel is a fixed 400pt that matches neither.
    static func blockSize(containerWidth: CGFloat) -> CGFloat {
        guard containerWidth > 0 else { return defaultSize }
        // Two edge insets and one gap, with two blocks filling the rest.
        let available = containerWidth - edgeInset * 2 - blockGap
        return min(max(available / 2, minimumSize), defaultSize)
    }
}

enum AlertIntensityTextColor {
    static func color(for intensity: String, colorScheme: ColorScheme) -> Color {
        switch intensity {
        case "1":
            return colorScheme == .dark
                ? Color(red: 0.72, green: 0.79, blue: 1.00)
                : Color(red: 0.26, green: 0.34, blue: 0.62)
        case "2":
            return colorScheme == .dark
                ? Color(red: 0.58, green: 0.76, blue: 1.00)
                : Color(red: 0.18, green: 0.42, blue: 0.70)
        case "4":
            return colorScheme == .dark
                ? Color(red: 1.00, green: 0.78, blue: 0.28)
                : Color(red: 0.90, green: 0.48, blue: 0.00)
        default:
            return intensity.isEmpty ? Color.primary : Color(intensity)
        }
    }
}

/// The width the card gives its content, handed down rather than measured.
///
/// Measuring from inside is circular here: the blocks cannot be compressed, so when the
/// size is too large the content inflates the very view a GeometryReader would measure,
/// and the loop has a stable fixed point at the maximum block size. It locks there on the
/// first frame — the fallback size is itself wide enough to inflate the measurement — and
/// never recovers. The card knows its width from its own proposal, so it states it.
private struct CardContentWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var cardContentWidth: CGFloat {
        get { self[CardContentWidthKey.self] }
        set { self[CardContentWidthKey.self] = newValue }
    }
}
