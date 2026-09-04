//
//  EEWDetailBlock.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/5.
//
///  2026/08/24 Changelog - Albert
///   - Added missing localizations for this part 新增字串的英文及日文翻譯
///

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
    @State private var clockTick = Date()
    /// Tapping the origin time swaps between "3 minutes ago" and the exact timestamp.
    /// Persisted, because someone who wants exact times wants them every launch, and
    /// re-tapping during an earthquake is not when to make them ask again.
    @AppStorage("showsAbsoluteOriginTime") private var showsAbsoluteOriginTime = false
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
    
    /// What the header actually shows: relative by default, absolute once tapped.
    var originTimeDisplayStr: String {
        showsAbsoluteOriginTime ? originTimeFormattedStr : relativeOriginTimeStr
    }

    /// The progression iOS uses on a notification, which stops counting once counting stops
    /// being the useful thing to say:
    ///
    ///     under a minute   Just now, then 42 sec ago
    ///     under an hour    38 min ago
    ///     up to 3 hours    2h ago
    ///     later today      15:32
    ///     yesterday        Yesterday 15:32
    ///     within a week    Tue 15:32
    ///     older            the full timestamp
    ///
    /// Abbreviated deliberately — "min" and "h", not "minutes" and "hours". This sits in a
    /// row that also has to hold a place name.
    ///
    /// RelativeDateTimeFormatter cannot express this: it counts all the way up ("5 hours
    /// ago", "3 days ago") and has no notion of switching to a clock time, so the rules are
    /// spelled out here.
    var relativeOriginTimeStr: String {
        relativeOriginTimeStr(now: clockTick)
    }

    private func relativeOriginTimeStr(now: Date) -> String {
        let elapsed = now.timeIntervalSince(originTime)
        // A clock skewed behind CWA's would otherwise render the future as "0 sec ago".
        guard elapsed >= 0 else { return originTimeFormattedStr(now: now) }

        if elapsed < 10 { return String(localized: "origin-time-just-now") }
        if elapsed < 60 {
            return String(format: String(localized: "origin-time-seconds-ago"),
                          Int(elapsed.rounded(.down)))
        }
        if elapsed < 3600 {
            return String(format: String(localized: "origin-time-minutes-ago"),
                          Int(elapsed / 60))
        }
        if elapsed <= 3 * 3600 {
            return String(format: String(localized: "origin-time-hours-ago"),
                          Int(elapsed / 3600))
        }

        // Past three hours "5h ago" is arithmetic the reader has to undo, so switch to the
        // clock. Dates are figured in Taiwan time, like the absolute formatter below —
        // these are Taiwan earthquakes, and a traveller should not see the day shift.
        let zone = TimeZone(secondsFromGMT: 8 * 3600)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = zone
        timeFormatter.setLocalizedDateFormatFromTemplate("HHmm")
        let time = timeFormatter.string(from: originTime)

        if calendar.isDate(originTime, inSameDayAs: now) { return time }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(originTime, inSameDayAs: yesterday) {
            return String(format: String(localized: "origin-time-yesterday"), time)
        }

        if let days = calendar.dateComponents([.day],
                                              from: calendar.startOfDay(for: originTime),
                                              to: calendar.startOfDay(for: now)).day,
           days < 7 {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.timeZone = zone
            weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")
            return "\(weekdayFormatter.string(from: originTime)) \(time)"
        }

        return originTimeFormattedStr(now: now)
    }

    var originTimeFormattedStr: String {
        originTimeFormattedStr(now: clockTick)
    }

    private func originTimeFormattedStr(now: Date) -> String {
        let elapsed = now.timeIntervalSince(originTime)
        if EarthquakeActivity.isActive(arrivalTime: arrivalTime, magnitude: magnitude, now: now),
           elapsed >= 0,
           elapsed < 120 {
            let totalSeconds = Int(elapsed.rounded(.down))
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            if minutes == 0 {
                return "\(seconds) 秒前"
            }
            return "\(minutes) 分 \(seconds) 秒前"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = dateFormatter.timeZone

        if calendar.isDate(originTime, inSameDayAs: now) {
            dateFormatter.dateFormat = " HH:mm:ss"
            return String(localized: "today-string") + dateFormatter.string(from: originTime)
        }

        let currentYear = calendar.component(.year, from: now)
        let eventYear = calendar.component(.year, from: originTime)

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
            AlertStatusBar(arrivalTime: arrivalTime, intensity: intensity, magnitude: magnitude)
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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            clockTick = now
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
                // The place name takes whatever the time does not need, rather than the two
                // splitting the row arbitrarily. An English placemark from CLGeocoder is
                // several times longer than the Chinese one, and this is the more important
                // of the two during an earthquake.
                EEWDetailHeaderLocation(locationName: locationName ?? fetchOceanData(lat: latB, lon: lonB))
                    .frame(maxWidth: .infinity, alignment: .leading)
                EEWDetailHeaderOriginTime(originTimeText: originTimeDisplayStr) {
                    showsAbsoluteOriginTime.toggle()
                }
                .layoutPriority(1)
            }
        }
    }

    private var report: ReportTitle {
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
                // The word and the number take different fonts, so they are different Texts.
                // "Depth" is a word and reads as code in mono; the number stays monospaced
                // because it changes between reports and mono is what stops it jittering.
                Text("alert-depth-label")
                    .font(.system(size: UIScreen.isZoomed ? 14 : 16))
                    .foregroundStyle(Color("TimeText"))
                Text(String(format: String(localized: "alert-depth-value"), depth))
                    .font(.system(size: UIScreen.isZoomed ? 14 : 16).monospaced())
                    .foregroundStyle(Color("TimeText"))
                    .padding(.leading, 3)
            }
        }
        .lineLimit(1)
    }
}

private struct EEWDetailHeaderLocation: View {
    let locationName: String

    private var font: Font { .system(size: UIScreen.isZoomed ? 14 : 20).bold() }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Image(systemName: "target")
                .font(.system(size: UIScreen.isZoomed ? 10 : 18))
            // Scrolls instead of truncating. The tail of a place name is often what
            // identifies it — "花蓮縣近海" and "花蓮縣" are different places — and an
            // English placemark is long enough that the tail is what gets cut.
            MarqueeText(text: locationName, font: font)
        }
    }
}

struct EEWDetailHeaderReport: View {
    let report: ReportTitle

    private var font: Font {
        .system(size: UIScreen.isZoomed ? 12 : 18)
    }

    var body: some View {
        HStack(spacing: 4) {
            if let prefix = report.prefix {
                Text(prefix)
                    .font(font.bold())
                    .foregroundStyle(ReportTitle.prefixColor)
            }
            Text(report.text)
                .foregroundStyle(report.badge?.foreground ?? Color("TimeText"))
                .font(report.badge == nil ? font : font.bold())
        }
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

/// Tap to swap between the relative and the exact time.
///
/// The 發生 suffix is gone. It was appended in every language, so English read
/// "2026/09/04 15:30:12 發生", and a relative time does not want a verb after it anyway.
private struct EEWDetailHeaderOriginTime: View {
    let originTimeText: String
    let onTap: () -> Void

    var body: some View {
        Text(originTimeText)
            .foregroundStyle(Color("TimeText"))
            .font(.system(size: UIScreen.isZoomed ? 12 : 18))
            .lineLimit(1)
            // "5 minutes ago" is wider than 5分鐘前, and this yields before the place name.
            .minimumScaleFactor(0.7)
            // The text alone is a thin tap target; the rectangle makes the whole slot work.
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .accessibilityAddTraits(.isButton)
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
