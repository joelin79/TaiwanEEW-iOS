//
//  EEWDetailBlock.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/5.
//

import SwiftUI
import XMLCoder
import CoreLocation
import os.log

struct EEWDetailBlock: View {
    let cornerRad: CGFloat = 10
    @ObservedObject var eventManager: EventDispatcher
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "EEWDetailBlock")
    
    
    var originTime: Date {eventManager.originTime}
    var publishedTime: Date {eventManager.publishedTime}
    var arrivalTime: Date {eventManager.arrivalTime}
    var status: String? {eventManager.event.last?.status.lowercased()}
    var msgType: String? {eventManager.event.last?.msgType.lowercased()}
    
    @State private var locationName: String? = nil
    var maxInt: String {eventManager.maxIntensity}
    var magnitude: Double {eventManager.magnitude}
    var depth: Double {eventManager.depth}
    var intensity: String {eventManager.intensity}
    var eqSeq: Int {eventManager.eqSeq}
    var lonB: Double {eventManager.lonB}
    var latB: Double {eventManager.latB}
    var pgaAdj: Double {eventManager.pgaAdj}
    
    var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        return formatter
    }()
    
    var originTimeFormattedStr: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let eventYear = Calendar.current.component(.year, from: originTime)
        
        if currentYear == eventYear {
            dateFormatter.dateFormat = "MM/dd HH:mm:ss"
        } else {
            dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        }
        return dateFormatter.string(from: originTime)
    }
    
    /// Handed down by whatever is presenting this — see CardContentWidthKey for why it
    /// cannot be measured here. Falls back to the screen for the legacy full-width card,
    /// which is the one case where the two agree.
    @Environment(\.cardContentWidth) private var cardContentWidth
    private var contentWidth: CGFloat {
        cardContentWidth > 0 ? cardContentWidth : UIScreen.screenWidth
    }

    private var blockSize: CGFloat { AlertBlockMetrics.blockSize(containerWidth: contentWidth) }

    /// The blocks are centred in what is left after the fixed inset, so their outer edges
    /// sit exactly one inset in. Every other row uses the same value, which is what keeps
    /// the header, the status bar and the blocks on one pair of edges.
    private var contentInset: CGFloat { AlertBlockMetrics.edgeInset }

    var body: some View {
        VStack(alignment: .leading, spacing: 0){
            if Device.deviceType == .ipad {
                Spacer()
            }
            pageTitle
            // Below the earthquake's own details and above the local prediction, where it
            // reads as the heading for the intensity and countdown rather than a banner
            // over the whole card.
            AlertStatusBar(arrivalTime: arrivalTime, intensity: intensity)
                .padding(.top, 10)
            alertInfo
                .padding(.top, AlertBlockMetrics.blockGap)
//            EEWDetailBlock(eventManager: eventManager)
//                .padding(.bottom, 10)
            
            
//                arrivalClockTimeBar.offset(x:UIScreen.baseLine)   TODO: Remove
            if Device.deviceType == .ipad {
                Spacer()
            }
//                testflightReminder.padding()
        }
        .padding(.horizontal, contentInset)
        .onAppear {
            updateLocationName()
        }.onChange(of: [lonB, latB]) { _ in
            updateLocationName()
        }
    }

    private var pageTitle: some View {
        VStack(spacing: 0) {
            // Baseline, not centre. The two sides are set at different sizes, so centring
            // aligns their text boxes — and a text box is glyphs plus the font's leading,
            // which differs with size. Matching baselines is what makes the text itself
            // sit on one line.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                EEWDetailHeaderMagnitude(depth: depth, magnitude: magnitude)
                Spacer(minLength: 8)
                EEWDetailHeaderReport(report: report)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                EEWDetailHeaderLocation(locationName: locationName ?? fetchOceanData(lat: latB, lon: lonB))
                Spacer(minLength: 8)
                EEWDetailHeaderOriginTime(originTimeText: "\(originTimeFormattedStr) 發生")
            }
        }
    }

    private var report: (title: String, badge: ReportBadge?) {
        ReportPresentation.headerTitle(status: status, msgType: msgType, eqSeq: eqSeq)
    }

    var alertInfo: some View {
        HStack(spacing: AlertBlockMetrics.blockGap) {
            IntensityBlock(intensity: intensity, size: blockSize)
            TimeBlock(arrivalTime: arrivalTime, size: blockSize)
        }
        .frame(maxWidth: .infinity)
    }
    
    var arrivalClockTimeBar: some View {
        Group {
            HStack (alignment: .center) {
                ZStack {
                    Rectangle().frame(width: 170.0, height: 40.0).clipped().cornerRadius(/*@START_MENU_TOKEN@*/7.0/*@END_MENU_TOKEN@*/).foregroundColor(Color("Pad"))
                    Text("est-arrival-time-string").font(.system(size:20))
                }
                Text(dateFormatter.string(from: arrivalTime)).font(.system(size: 20))
            }
        }
    }
    
    private func updateLocationName() {
        Task {
            locationName = await fetchLocationName(lat: latB, lon: lonB)
        }
    }
    
    func fetchLocationName(lat: Double, lon: Double) async -> String? {
        await EpicenterName.resolve(lat: lat, lon: lon)
    }

    func fetchOceanData(lat: Double, lon: Double) -> String {
        EpicenterName.oceanArea(lat: lat, lon: lon)
    }
}

private struct EEWDetailHeaderMagnitude: View {
    let depth: Double
    let magnitude: Double

    private var magnitudeColor: Color {
        if magnitude >= 7 { return .purple }
        if magnitude >= 6.5 { return .red }
        if magnitude > 5.5 { return .orange }
        return .primary
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("M\(String(format: "%.1f", magnitude))")
                .bold()
                .foregroundStyle(magnitudeColor)
                .font(.system(size: UIScreen.isZoomed ? 19 : 24).monospaced().bold())
            HStack(alignment: .firstTextBaseline, spacing: 0) {
//                Image(systemName: "water.waves.and.arrow.down")
//                    .font(.system(size: UIScreen.isZoomed ? 22 : 12))
//                    .foregroundStyle(Color("TimeText"))
                Text("\(String(format: "深度%.1f", depth))km")
                    .font(.system(size: UIScreen.isZoomed ? 14 : 16).monospaced())
                    .foregroundStyle(Color("TimeText"))
            }
        }
        .lineLimit(1)
    }
}

private struct EEWDetailHeaderLocation: View {
    let locationName: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Image(systemName: "target")
                .font(.system(size: UIScreen.isZoomed ? 10 : 18))
            Text(locationName)
                .font(.system(size: UIScreen.isZoomed ? 14 : 20).bold())
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

struct EEWDetailHeaderReport: View {
    let report: (title: String, badge: ReportBadge?)

    var body: some View {
        Text(report.title)
            .foregroundStyle(report.badge?.foreground ?? Color("TimeText"))
            .font(report.badge == nil
                  ? .system(size: UIScreen.isZoomed ? 12 : 18)
                  : .system(size: UIScreen.isZoomed ? 12 : 18).bold())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            // Padding only when there is something to pad against, so an ordinary report
            // still sits on the same baseline as the magnitude opposite it.
            .padding(.horizontal, report.badge == nil ? 0 : 8)
            .padding(.vertical, report.badge == nil ? 0 : 3)
            .background {
                if let badge = report.badge {
                    Capsule(style: .continuous).fill(badge.background)
                }
            }
    }
}

private struct EEWDetailHeaderOriginTime: View {
    let originTimeText: String

    var body: some View {
        Text(originTimeText)
            .foregroundStyle(Color("TimeText"))
            .font(.system(size: UIScreen.isZoomed ? 12 : 18))
            .lineLimit(1)
    }
}

//private struct DescText: View {
//    let title: String
//    let subtitle: String
//    let val: String
//    let unit: String
//    let widthRatio: CGFloat
//    let smallText: Bool
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0){
//            HStack {
//                Rectangle()
//                    .frame(width: 3, height: 35)
//                    .foregroundStyle(Color("SecondaryField"))
//                HStack{
//                    VStack(alignment: .leading) {
//                        Text(title)
//                            .font(.system(size: 12))
//                            .fontWeight(.bold)
//                        Text(subtitle)
//                            .font(.system(size: 10))
//                            .fontWeight(.light)
//                    }
//                    Spacer()
//                    HStack(alignment: .firstTextBaseline, spacing: 5){
//                        Text(val)
//                            .font(.system(size: smallText ? 20 : 28))
//                        Text(unit)
//                            .font(.system(size: 18))
//                            .frame(height: 10)
//                    }
//                    
//                }
//            }
//            .frame(width: UIScreen.screenWidth * widthRatio, height: 35)
//            Rectangle()
//                .frame(width: UIScreen.screenWidth * widthRatio, height: 1)
//                .foregroundStyle(Color("SecondaryField"))
//        }
//    }
//}

#Preview {
    VStack {
        // Preview with default values
//        EEWDetailBlock(eventManager: EventDispatcher(cityIndex: 0, districtIndex: 0, startListening: false))
        
        // iPad Component
        VStack {
            Spacer()
            EEWDetailBlock(eventManager: EventDispatcher(cityIndex: 0, districtIndex: 0, startListening: false))
            Spacer()
        }
        .frame(width: 400, height: 310)
        .background(
            RoundedRectangle(cornerRadius: 35)
                .stroke(Color.blue, lineWidth: 1)
        )
    }
}

#Preview("Report titles") {
    // Drives EEWDetailBlock.report directly, so this shows the real mapping. isDebugBuild
    // is forced false because the Testing badge is suppressed in debug builds by design.
    let cases: [(String, String?, String?)] = [
        ("ordinary", "actual", "alert"),
        ("drill", "exercise", "alert"),
        ("testing", "test", "alert"),
        ("system", "system", "alert"),
        ("canceled", "actual", "cancel"),
        ("error", "actual", "error"),
        ("drill + cancel", "exercise", "cancel"),
        ("test + error", "test", "error"),
        ("system + cancel", "system", "cancel"),
    ]

    return VStack(alignment: .trailing, spacing: 12) {
        ForEach(cases, id: \.0) { label, status, msgType in
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                EEWDetailHeaderReport(
                    report: ReportPresentation.headerTitle(status: status, msgType: msgType,
                                                           eqSeq: 3, isDebugBuild: false))
            }
        }
    }
    .padding()
    .environment(\.locale, Locale(identifier: "zh-Hant"))
}
