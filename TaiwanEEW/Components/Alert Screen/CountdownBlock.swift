//
//  TimeBlock.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/8/18.
//

import SwiftUI

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

    /// Falls back to a live reading so the first frame is right rather than blank.
    private var remaining: Double { max(-Date().timeIntervalSince(arrivalTime), 0) }
    private var value: Double { tick ?? remaining }

    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
            .fill(Color("Pad"))
            .clipped()
            .overlay(content)
            // Draw border
            .overlay(RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
                .stroke(Color("EqInfoBoarder"), lineWidth: 2))
            .frame(width: size, height: size)
    }
    
    var content: some View {
        VStack{
            Text("arrival-string")
                .font(.system(size: UIScreen.isZoomed ? 30 : 34).weight(.medium))
            HStack(alignment: .bottom){
                Text(String(Int(value)))
                    .font(.system(size: value > 99 ? 45 : UIScreen.isZoomed ? 75 : 80, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .onReceive(
                        Timer.publish(every: AlertBlink.tick, on: .main, in: .common).autoconnect(),
                        perform: { _ in
                            tick = remaining
                        }
                    )
                Text("seconds-string")
                    .font(.system(size: UIScreen.isZoomed ? 28 : 30, weight: .bold, design: .monospaced ))
            }
        }
    }
}

struct TimeBlock_Previews: PreviewProvider {
    static var previews: some View {
        TimeBlock(arrivalTime: Date())
    }
}
