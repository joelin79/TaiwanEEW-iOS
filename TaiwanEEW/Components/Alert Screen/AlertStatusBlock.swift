//
//  AlertStatusBar.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/2/18.
//

import SwiftUI
import Combine

struct AlertStatusBar : View {
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    /// Fast enough that the blink lands on the same frame the countdown changes; the state
    /// it writes is one Double, and only when the value actually differs.
    let blinkTimer = Timer.publish(every: AlertBlink.tick, on: .main, in: .common).autoconnect()
    var arrivalTime: Date
    var intensity: String
    /// Sets how long the bar stays in its alert state — see EarthquakeActivity.gracePeriod.
    var magnitude: Double = 0
    let cornerRad: CGFloat = 10
    @State private var opacity: Double = 1
    @State private var fillColor: Color = .green
    @State private var isAlert: Bool = false
    @State private var isMajor: Bool = false
    @State private var isUpdated: Bool = false     // used to indicate if arrivalTime is updated to non-default value (1970/1/1)
    /// While an alert is live the label alternates with what to actually do about it.
    @State private var showsSafetyAdvice: Bool = false

    private static let dimOpacity: Double = 0.5
    private static let blinksPerMessage = 3

    
    var strLocL = NSLocalizedString("loading-string", comment: "")
    var strLoc1 = NSLocalizedString( "alert-status-1-string", comment: "")
    var strLoc2 = NSLocalizedString( "alert-status-2-string", comment: "")
    var strLoc3 = NSLocalizedString( "alert-status-3-string", comment: "")
    var strAdvice = NSLocalizedString("alert-safety-advice-string", comment: "")
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
            .fill((isUpdated) ? (isAlert) ? (isMajor) ? Color("Warning") : Color("Caution") : Color("Safe") : Color.gray)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
                    // SafeBoarder, not black. It pairs with the Safe fill the way the
                    // other two pair with theirs, and existed unused while this branch
                    // hardcoded black — which left the calm state quiet in fill and the
                    // loudest thing on the card in outline.
                    .strokeBorder(((isUpdated) ? (isAlert) ? (isMajor) ? Color("WarningBoarder") : Color("CautionBoarder") : Color("SafeBoarder") : Color.black))
            )
            // Flexible, not a fixed width. It was baseLine+340, and since baseLine is
            // (screenWidth-340)/3 with EEWDetailBlock padding baseLine on both sides, the
            // three summed to exactly screenWidth — incompressible and therefore always
            // 20pt too wide for a card inset from the screen edges.
            .frame(maxWidth: .infinity, minHeight: 30.0, maxHeight: 30.0)
            .clipped()
            .overlay(
                HStack {
                    Image(systemName: (isUpdated) ? (isAlert) ? (isMajor) ? "exclamationmark.triangle" : "exclamationmark.triangle" : "dot.radiowaves.up.forward" : "circle.dotted" )
                        .foregroundStyle((isMajor) ? .white : .black)
                        .font(.system(size: 18).bold().monospaced())
                        
                    StrokeText(text: label, width: (isMajor) ? 0.75 : 0, color: .black)
                        .foregroundStyle((isMajor) ? .white : .black)
                        .font(.system(size: 18).bold().monospaced())
                }
            )
            .opacity(opacity)

            .onReceive(blinkTimer) { _ in
                updateBlinkPhase()
            }
            .onReceive(timer) { _ in
                updateAlert()
            }
            .onAppear {
                updateAlert()
            }
    }

    private var label: String {
        guard isUpdated else { return strLocL }
        guard isAlert else { return strLoc1 }
        if showsSafetyAdvice { return strAdvice }
        return isMajor ? strLoc3 : strLoc2
    }

    private func updateAlert() {
        
        // updates isInAlert (true until the grace period after wave arrival). Shared with
        // the map's blinking epicenter so the two cannot disagree about whether an
        // earthquake is in progress.
        let isInAlert = EarthquakeActivity.isActive(arrivalTime: arrivalTime, magnitude: magnitude)
        if isInAlert != isAlert {
            isAlert = isInAlert
            if !isAlert {
                // Back to the status line, so a finished alert never leaves the advice
                // frozen on screen. Opacity is restored by updateBlinkPhase.
                showsSafetyAdvice = false
            }
        }
        
        // updates isUpdate
        if arrivalTime > Date(timeIntervalSince1970: 1000){
            isUpdated = true
        } else {
            isUpdated = false       // Note: AlertView defaults arrivalTime value to 1970/1/1 before firebase is connected
        }
        
        // updates isMajor
        if (isAlert && intensity.first!.wholeNumberValue! >= 4 ) {
            isMajor = true
        } else {
            isMajor = false
        }
    }
    
    /// Derived from the time to arrival, not from a repeating animation. A repeatForever
    /// animation starts whenever the alert starts and drifts against the countdown from
    /// then on; taking the phase from the same quantity the countdown displays means the
    /// two cannot disagree.
    ///
    /// Lit for the first half of each second so the bar brightens exactly as the number
    /// changes: remaining decreases, so its fractional part wraps 0 -> 1 at each tick.
    private func updateBlinkPhase() {
        guard isAlert else {
            if opacity != 1 { opacity = 1 }
            return
        }
        let next = AlertBlink.isLit(arrivalTime: arrivalTime) ? 1 : Self.dimOpacity
        if opacity != next { opacity = next }

        // Derived rather than toggled on its own timer, so the wording changes on a tick
        // together with the blink instead of drifting against it. Only while something is
        // happening: telling someone to take cover with nothing coming teaches them to
        // ignore it.
        let advice = isAlert && AlertBlink.showsAlternate(arrivalTime: arrivalTime,
                                                          everyBlinks: Self.blinksPerMessage)
        if showsSafetyAdvice != advice { showsSafetyAdvice = advice }
    }
    
}

struct StrokeText: View {
    let text: String
    let width: CGFloat
    let color: Color

    var body: some View {
        ZStack{
            ZStack{
                Text(text).offset(x:  width, y:  width)
                Text(text).offset(x: -width, y: -width)
                Text(text).offset(x: -width, y:  width)
                Text(text).offset(x:  width, y: -width)
            }
            .foregroundColor(color)
            Text(text)
        }
    }
}

struct AlertStatusBar_Preview : PreviewProvider {
    static var previews: some View {
        AlertStatusBar(arrivalTime: Date(), intensity: "3", magnitude: 5.0).environment(\.locale, Locale.init(identifier: "zh-Hant"))
    }
    
}
