//
//  CompactAlertBlock.swift
//  TaiwanEEW
//
//  The alert content at the card's compressed position.
//
//  An early warning has to answer two questions in the first two seconds: how hard
//  will it shake here, and how long until it does. Those keep full weight. Everything
//  else the full block shows — report number, origin time, depth, the title itself —
//  is a drag away, so it is dropped rather than shrunk into illegibility.
//
//  Deliberately a pure presentation view: it takes resolved values rather than the
//  dispatcher, so the epicenter geocoding stays in one place and this can be previewed
//  in every state without a live event.
//

import SwiftUI

struct CompactAlertBlock: View {
    var intensity: String
    var arrivalTime: Date
    var magnitude: Double
    var depth: Double
    var locationName: String
    @Environment(\.colorScheme) private var colorScheme

    private var intensityValue: Int { EEWService.intensityStringToValue(str: intensity) }

    // Written as explicitly-typed properties rather than inline ternary chains. Mixing
    // .purple/.red/.orange with Color(...) in one expression leaves the compiler unifying
    // ShapeStyle conformances across every branch, which is slow enough to time out the
    // preview build even though a full xcodebuild survives it.
    private var magnitudeColor: Color {
        if magnitude >= 7 { return .purple }
        if magnitude >= 6.5 { return .red }
        if magnitude > 5.5 { return .orange }
        return .primary
    }

    /// Same threshold as IntensityBlock — red from 4 up, where shaking starts being
    /// something to act on rather than notice.
    private var intensityBorder: Color {
        intensityValue >= 4 ? Color.red : Color("EqInfoBoarder")
    }

    private var compactIntensityColor: Color {
        AlertIntensityTextColor.color(for: intensity, colorScheme: colorScheme)
    }

    /// The app stores intensities as "5-" / "5+", which is what the colour assets and
    /// EEWService.intensityStringToValue are keyed on — so the raw token is still what
    /// gets looked up. This is presentation only: CWA writes them 弱 and 強, and the
    /// suffix is set smaller than the digit the way the agency renders it.
    ///
    /// Hardcoded rather than localized because the surrounding copy in this view is too:
    /// the epicenter name is geocoded zh-Hant for every locale. Worth revisiting together.
    private var intensityParts: (value: String, suffix: String?) {
        switch intensity {
        case "5-": return ("5", "弱")
        case "5+": return ("5", "強")
        case "6-": return ("6", "弱")
        case "6+": return ("6", "強")
        default: return (intensity.isEmpty ? "–" : intensity, nil)
        }
    }

    /// Intensity pinned leading, countdown pinned trailing, epicenter stuck to the
    /// intensity. maxWidth .infinity is what makes that true — without it the row sizes
    /// to its content and the Spacer has nothing to push against.
    var body: some View {
        VStack(spacing: AlertBlockMetrics.blockGap) {
            // The same bar the expanded card shows, above the row for the same reason it
            // sits above the blocks there. Collapsing should not cost the one line that
            // says whether anything is happening at all — and while an alert is live this
            // is what carries 趴下、掩護、穩住, which is the last thing to drop.
            AlertStatusBar(arrivalTime: arrivalTime, intensity: intensity)

            HStack(spacing: 8) {
                intensityPill
                context
                Spacer(minLength: 6)
                countdownPill
            }
            .frame(maxWidth: .infinity)
        }
        // Matches EEWDetailBlock so collapsed and expanded content sit on the same edges.
        .padding(.horizontal, AlertBlockMetrics.edgeInset)
    }

    private var intensityPill: some View {
        StatPill(borderColor: intensityBorder) {
            Text(intensityParts.value)
                .font(PillMetrics.intensityValueFont.monospaced())
                .foregroundColor(compactIntensityColor)
            if let suffix = intensityParts.suffix {
                // Set at the digit's size and colour so "5弱" reads as one value rather
                // than a number with an annotation.
                Text(suffix)
                    .font(PillMetrics.intensityValueFont)
                    .foregroundColor(compactIntensityColor)
            }
            if !String(localized: "compact-intensity-unit").isEmpty {
                Text("compact-intensity-unit")
                    .font(.system(size: PillMetrics.unit, weight: .bold, design: .monospaced))
            }
        }
    }

    private var countdownPill: some View {
        CountdownPill(arrivalTime: arrivalTime)
    }

    /// Magnitude keeps the severity colouring it has in the full block, so the one piece
    /// of context that survives still reads at a glance. Depth follows it in the muted
    /// treatment and with the same icon the full block uses.
    private var context: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(locationName)
                .font(.system(size: 20).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            HStack(spacing: 3) {
                Text("M\(String(format: "%.1f", magnitude))")
                    .font(.system(size: 16, design: .monospaced).bold())
                    .foregroundStyle(magnitudeColor)
                Image(systemName: "water.waves.and.arrow.down")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("TimeText"))
                Text("\(String(format: "%.1f", depth))km")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(Color("TimeText"))
            }
            // lineLimit alone stops the wrap; scaling rather than fixedSize leaves this
            // row compressible, so it — not the card's width — gives when space is short.
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

}

/// Display Zoom is what the rest of the alert screen keys its type off, so the compact
/// block follows the same convention rather than introducing a second one.
private enum PillMetrics {
    static var label: CGFloat { UIScreen.isZoomed ? 12 : 14 }
    static var value: CGFloat { UIScreen.isZoomed ? 24 : 28 }
    static var unit: CGFloat { UIScreen.isZoomed ? 12 : 14 }
    static var pillHeight: CGFloat { UIScreen.isZoomed ? 43 : 48 }
    static var valueFont: Font { .system(size: value, weight: .bold) }
    static var intensityValueFont: Font { .system(size: value + 5, weight: .bold) }
}

/// The 170pt square blocks reduced to a bar-height pill: same fill, same continuous
/// corner, same border, laid out along the baseline instead of stacked.
private struct StatPill<Content: View>: View {
    let borderColor: Color
    @ViewBuilder var content: Content

    /// Pinned to its ideal width so the labels never wrap — the prefix breaking to a second
    /// line changed the pill's height and made the row jump between reports. The epicenter
    /// column is the flexible one and absorbs the squeeze by scaling its name down.
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            content
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 9)
        .frame(height: PillMetrics.pillHeight)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color("Pad"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 2)
        )
    }
}

/// Clamps at zero — a wave that has already passed should read as arrived, not count
/// into the negative.
///
/// The displayed value falls back to a live reading rather than waiting for the first
/// tick, so the very first frame is right. Seeding it from onAppear instead showed 0
/// until a whole tick had elapsed, which is the worst possible moment to be wrong.
private struct CountdownPill: View {
    let arrivalTime: Date
    @State private var tick: Double?
    @State private var isLit = true

    /// Tenths need ten times the refresh rate to be worth showing at all. It also sets how
    /// precisely the blink can land — a toggle can be up to one interval late.
    private static let interval: TimeInterval = 0.1

    /// How long 已抵達 keeps flashing after the wave lands. Shorter than
    /// EarthquakeActivity.gracePeriod on purpose: the grace period governs how long the
    /// alert stays live, this governs how long it demands attention.
    private static let flashWindow: TimeInterval = 15

    /// Phase comes from AlertBlink so this, the status bar, the banner and the epicenter
    /// are lit and dim together. Only the depth of the dim is local — a small marker and a
    /// full-width bar do not need the same amount.
    private static let dimOpacity: Double = 0.30

    private var remaining: Double { max(-Date().timeIntervalSince(arrivalTime), 0) }
    private var value: Double { tick ?? remaining }
    /// Guarded on hasEvent, otherwise the 1970 default reads as arrived and a freshly
    /// launched app with no earthquake would sit there showing 已抵達.
    private var hasArrived: Bool {
        EarthquakeActivity.hasEvent(arrivalTime: arrivalTime) && value <= 0
    }

    /// Tenths only inside the last ten seconds. Further out they are noise — nobody acts
    /// on the difference between 42.3s and 42.4s — and they cost width the epicenter name
    /// wants. Close in, they are the part that is actually changing.
    ///
    /// Truncated to a tenth rather than formatted straight, because %.1f rounds: at 9.99
    /// it prints "10.0", so the tenths would appear reading 10.0 and then jump back to
    /// 9.9. Flooring first means the first value ever shown with a decimal is 9.9.
    private var label: String {
        if value < 10 {
            return String(format: "%.1f", (value * 10).rounded(.down) / 10)
        }
        return String(Int(value))
    }

    var body: some View {
        StatPill(borderColor: Color("EqInfoBoarder")) {
            if hasArrived {
                // Set at the digit's size so the pill keeps the same height, and it comes
                // out narrower than the counting state rather than wider.
                Text("抵達")
                    .font(.system(size: PillMetrics.value, weight: .bold))
            } else {
                Text("countdown-string")
                    .font(.system(size: PillMetrics.label).weight(.medium))
                // monospacedDigit rather than design: .monospaced. The monospaced *design*
                // gives the decimal point a full digit-width advance, which left it
                // floating in a gap on both sides; monospacedDigit fixes the width of
                // digits only, so the point sits tight while the number still stops
                // jittering as it counts down.
                Text(label)
                    .font(PillMetrics.valueFont)
                    .monospacedDigit()
                Text("seconds-string")
                    .font(.system(size: PillMetrics.unit, weight: .bold, design: .monospaced))
            }
        }
        // Square wave, deliberately not animated: no .animation modifier and no
        // withAnimation, so SwiftUI snaps between the two values instead of easing
        // through the range. The phase is computed from elapsed time rather than toggled
        // by a repeating animation, which is what keeps it a hard cut.
        .opacity(isLit ? 1 : Self.dimOpacity)
        .onReceive(Timer.publish(every: Self.interval, on: .main, in: .common).autoconnect()) { _ in
            tick = remaining

            let sinceArrival = Date().timeIntervalSince(arrivalTime)
            guard hasArrived, sinceArrival < Self.flashWindow else {
                isLit = true
                return
            }
            isLit = AlertBlink.isLit(arrivalTime: arrivalTime)
        }
    }
}

#Preview {
    CompactAlertBlock(intensity: "1",
                      arrivalTime: Date().addingTimeInterval(0),
                      magnitude: 5.0,
                      depth: 5.2,
                      locationName: "宜蘭縣蘇澳鎮")
    CompactAlertBlock(intensity: "4",
                      arrivalTime: Date().addingTimeInterval(50),
                      magnitude: 6.5,
                      depth: 15.2,
                      locationName: "宜蘭縣蘇澳鎮")
    CompactAlertBlock(intensity: "2",
                      arrivalTime: Date().addingTimeInterval(12),
                      magnitude: 7.0,
                      depth: 15.2,
                      locationName: "宜蘭縣蘇澳鎮")
}
