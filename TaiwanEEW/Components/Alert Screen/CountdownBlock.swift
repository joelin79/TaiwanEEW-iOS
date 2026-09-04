//
//  TimeBlock.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/8/18.
//

import SwiftUI

private extension VerticalAlignment {
    enum CountdownValueBaseline: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.lastTextBaseline]
        }
    }

    static let countdownValueBaseline = VerticalAlignment(CountdownValueBaseline.self)
}

struct TimeBlock: View {
    let cornerRad: CGFloat = 20
    var arrivalTime: Date
    /// See IntensityBlock.size.
    var size: CGFloat = AlertBlockMetrics.defaultSize
    
    /// Sampled at AlertBlink.tick rather than once a second. The value was always derived
    /// from the arrival time, but checking it only once a second meant the digit changed
    /// wherever the timer happened to start — on this view appearing — so it drifted
    /// against the collapsed card's countdown and against the status bar's blink. Sampling
    /// finely means it flips on the real boundary, which is what everything else uses.
    @State private var tick: Double?
    @State private var isLit = true

    /// Matches the compact countdown: tenths matter only near arrival, and this is frequent
    /// enough that both the decimal and the post-arrival flash land cleanly.
    private static let interval: TimeInterval = 0.1
    private static let flashWindow: TimeInterval = 15
    private static let dimOpacity: Double = 0.30

    /// Falls back to a live reading so the first frame is right rather than blank.
    private var remaining: Double { max(-Date().timeIntervalSince(arrivalTime), 0) }
    private var value: Double { tick ?? remaining }
    private var hasArrived: Bool {
        EarthquakeActivity.hasEvent(arrivalTime: arrivalTime) && value <= 0
    }

    /// Same display rule as the compact card: whole seconds until the final ten, then
    /// tenths floored so 9.99 appears as 9.9 rather than briefly rounding back to 10.0.
    private var label: String {
        if value < 10 {
            return String(format: "%.1f", (value * 10).rounded(.down) / 10)
        }
        return String(Int(value))
    }

    private var valueFontSize: CGFloat {
        if value < 10 {
            return UIScreen.isZoomed ? 62 : 66
        }
        return value > 99 ? 45 : UIScreen.isZoomed ? 75 : 80
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
            .fill(Color("Pad"))
            .clipped()
            .overlay(content)
            // Draw border
            .overlay(RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
                .stroke(Color("EqInfoBoarder"), lineWidth: 2))
            .frame(width: size, height: size)
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
    
    var content: some View {
        VStack{
            Text("countdown-string")
                // Matches IntensityBlock's title beside it. Do not lower this to make a
                // long translation fit: the two blocks sit side by side and are read as a
                // pair, and shrinking this one for every language to solve an English
                // problem makes 倒數 and あと smaller than the block they are paired with.
                .font(.system(size: UIScreen.isZoomed ? 30 : 34).weight(.medium))
                .lineLimit(1)
                // Length is the actual problem, so it is handled by length. The padding
                // keeps any title off the block edge; the scale factor then shrinks only
                // the ones that still do not fit, which is "Countdown" and nothing else.
                .padding(.horizontal, 6)
                .minimumScaleFactor(0.5)
            ZStack(alignment: Alignment(horizontal: .center, vertical: .countdownValueBaseline)) {
                referenceValueRow
                    .hidden()
                valueContent
            }
        }
    }

    @ViewBuilder
    private var valueContent: some View {
        if hasArrived {
            Text("alert-arrived")
                .font(.system(size: UIScreen.isZoomed ? 42 : 46, weight: .bold))
                .lineLimit(1)
                // As above: 已抵達 and 到達 keep the size the block was designed around,
                // and only "Arrived" scales.
                .padding(.horizontal, 6)
                .minimumScaleFactor(0.5)
                .alignmentGuide(.countdownValueBaseline) { dimensions in
                    dimensions[.lastTextBaseline] + (UIScreen.isZoomed ? 12 : 16)
                }
        } else {
            HStack(alignment: .bottom){
                Text(label)
                    .font(.system(size: valueFontSize, weight: .bold))
                    .monospacedDigit()
                Text("seconds-string")
                    .font(.system(size: UIScreen.isZoomed ? 28 : 30, weight: .bold, design: .monospaced ))
            }
            .alignmentGuide(.countdownValueBaseline) { dimensions in
                dimensions[.lastTextBaseline]
            }
        }
    }

    /// Invisible layout reference matching IntensityBlock's value row. The visible
    /// countdown can be decimal-sized or replaced by 已抵達 without moving the title or
    /// the value/unit baseline relative to the estimated intensity block beside it.
    private var referenceValueRow: some View {
        HStack(alignment: .bottom){
            Text("8")
                .font(.system(size: UIScreen.isZoomed ? 75 : 80, weight: .bold, design: .monospaced))
            Text("seconds-string")
                .font(.system(size: UIScreen.isZoomed ? 28 : 30, weight: .bold, design: .monospaced ))
        }
        .alignmentGuide(.countdownValueBaseline) { dimensions in
            dimensions[.lastTextBaseline]
        }
    }
}

struct TimeBlock_Previews: PreviewProvider {
    static var previews: some View {
        TimeBlock(arrivalTime: Date())
    }
}
