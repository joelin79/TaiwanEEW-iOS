//
//  AlertView.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/7/5.
//

import SwiftUI
import XMLCoder

struct AlertView: View {
    // Instance
    @ObservedObject var eventManager: EventDispatcher
    // binding from @main
//    @Binding var historyRange: TimeRange
    @Binding var subscribedCityIndex: Int
    @Binding var subscribedDistrictIndex: Int
    @Binding var notifyThreshold: NotifyThreshold
    var startupEnabled: Bool = true
    @Environment(\.colorScheme) var colorScheme
    var lastPingTime: Date {eventManager.lastPingTime}
    var originTime: Date {eventManager.originTime}
    var publishedTime: Date {eventManager.publishedTime}
    var arrivalTime: Date {eventManager.arrivalTime}
    var status: String? {eventManager.event.last?.status.lowercased()}
    var msgType: String? {eventManager.event.last?.msgType.lowercased()}
    
    @State private var locationName: String? = nil
    @State private var didRunStartupTasks = false
    /// Held here rather than inside the card so the map can frame around it.
    @State private var cardPosition: CardPosition = .middle
    /// Reported by whichever card is running. The map only ever sees this number, not
    /// which implementation produced it.
    @State private var cardObscuredHeight: CGFloat = 0
    var magnitude: Double {eventManager.magnitude}
    var depth: Double {eventManager.depth}
    var intensity: String {eventManager.intensity}
    var maxIntesityValue: Int {eventManager.maxIntensityValue}
    var eqSeq: Int {eventManager.eqSeq}
    var lonB: Double {eventManager.lonB}
    var latB: Double {eventManager.latB}
    var pgaAdj: Double {eventManager.pgaAdj}
    
    fileprivate func onAppLaunch() {
        // correct the transparency bug for Tab bars
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        // correct the transparency bug for Navigation bars
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "isFirstLaunchVer2.0.2")
        if (isFirstLaunch){
            NotificationManager.setNotifyMode(cityIndex: subscribedCityIndex, districtIndex: subscribedDistrictIndex, threshold: notifyThreshold)
        }
    }

    private func runStartupTasksIfNeeded() {
        guard startupEnabled, !didRunStartupTasks else { return }
        didRunStartupTasks = true
        onAppLaunch()
    }
    
    var body: some View {
        Group {
            if (Device.deviceType == .iphone) {
                iPhoneView
            } else {
                iPadView
            }
        }
        .onAppear {
            runStartupTasksIfNeeded()
        }
        .onChange(of: startupEnabled) { _ in
            runStartupTasksIfNeeded()
        }
    }
}

private extension AlertView {
    var iPhoneView: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .top)){
            AlertMapView(eventManager: eventManager,
                         cardObscuredHeight: cardObscuredHeight,
                         isCollapsed: cardPosition == .bottom)
                .ignoresSafeArea()
            ErrorBanner(msgType: msgType, status: status, arrivalTime: arrivalTime)
            
            HStack(alignment: .top){
                Legend(maxIntensityValue: maxIntesityValue)
//                    .padding(.top)
                    .offset(x:-UIScreen.baseLine/2)
                Spacer()
                ConnectionStatusButton(lastPingTime: lastPingTime)
                    .offset(x:UIScreen.baseLine/2)
            }.padding(.horizontal, UIScreen.baseLine)
            
            alertCard
        }
        .task(id: [latB, lonB]) {
            locationName = await EpicenterName.resolve(lat: latB, lon: lonB)
        }
        .analyticsScreen(name: "AlertView", extraParameters: [
            "watch_location" : Location.cities[subscribedCityIndex].district[subscribedDistrictIndex].districtName
        ])
    }
    
    /// iOS 17 and up get the floating card; 15–16 keep the frozen SlideOverCard. Chosen
    /// in one place so nothing else in this view has to branch.
    @ViewBuilder
    var alertCard: some View {
        if #available(iOS 17.0, *) {
            FloatingAlertCard(position: $cardPosition,
                              onSettle: { cardObscuredHeight = $0 }) {
                EEWDetailBlock(eventManager: eventManager)
            } compact: {
                CompactAlertBlock(intensity: intensity,
                                  arrivalTime: arrivalTime,
                                  magnitude: magnitude,
                                  depth: depth,
                                  locationName: locationName
                                    ?? EpicenterName.oceanArea(lat: latB, lon: lonB))
            }
        } else {
            SlideOverCard(slideDirection: .bottom,
                          position: $cardPosition,
                          onSettle: { cardObscuredHeight = $0 }) {
                EEWDetailBlock(eventManager: eventManager)
            }
        }
    }

    var iPadView: some View {
        ZStack (alignment: Alignment(horizontal: .center, vertical: .top)) {
            // iPad puts the detail panel beside the map, so nothing is covered and the
            // framing has no card to work around.
            AlertMapView(eventManager: eventManager, cardObscuredHeight: 0,
                         isCollapsed: false)
                .ignoresSafeArea()
            ErrorBanner(msgType: msgType, status: status, arrivalTime: arrivalTime)
            
            HStack (alignment: .top) {
                VStack(alignment: .leading, spacing: 10){
                    Spacer()
                    Legend(maxIntensityValue: maxIntesityValue)
                    ConnectionStatusButton(lastPingTime: lastPingTime)
                }
                .padding(.leading, 20)
                .padding(.bottom, 10)
                
                Spacer()
                
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 36)
                        .fill(.clear)
                        .frame(width: 400, height: 310)
                        .background(.regularMaterial)
                        .overlay(
                            VStack {
                                Spacer()
                                EEWDetailBlock(eventManager: eventManager)
                                Spacer()
                            }
                            // The panel is a fixed 400pt, which matches neither the screen
                            // nor the phone card.
                            .environment(\.cardContentWidth, 400)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.trailing, 20)
                        .padding(.bottom, 10)
                }
                    
            }

            
        }
        .analyticsScreen(name: "AlertView", extraParameters: [
            "watch_location" : Location.cities[subscribedCityIndex].district[subscribedDistrictIndex].districtName
        ])
    }
}

// MARK: - Components

struct AlertView_Previews: PreviewProvider {
    @State static var testCityIndex = 0
    @State static var testDistrictIndex = 0
    @State static var testThr = NotifyThreshold.eg1
    
    static var previews: some View {
        AlertView(eventManager: EventDispatcher(cityIndex: testCityIndex, districtIndex: testDistrictIndex, startListening: false), subscribedCityIndex: $testCityIndex, subscribedDistrictIndex: $testDistrictIndex, notifyThreshold: $testThr ).environment(\.locale, Locale.init(identifier: "zh-Hant"))
        
        AlertView(eventManager: EventDispatcher(cityIndex: testCityIndex, districtIndex: testDistrictIndex, startListening: false), subscribedCityIndex: $testCityIndex, subscribedDistrictIndex: $testDistrictIndex, notifyThreshold: $testThr).environment(\.colorScheme, .dark)
    }
}

/// The loud version of a special-case report, over the map. The card header shows the
/// same thing quietly as a badge; both take their wording and colour from
/// ReportPresentation so they cannot disagree.
struct ErrorBanner: View {
    var msgType: String?
    var status: String?
    /// Only so the flash can share AlertBlink's phase with everything else on screen.
    var arrivalTime: Date = .distantPast

    var body: some View {
        let facets = ReportPresentation.facets(status: status, msgType: msgType)

        VStack(spacing: 10) {
            // Both are shown when both apply — a cancelled drill is two facts, and the
            // message half is first because it is what changed.
            if let message = facets.message {
                SpecialCaseBanner(facet: message, arrivalTime: arrivalTime)
            }
            if let status = facets.status {
                SpecialCaseBanner(facet: status, arrivalTime: arrivalTime)
            }
        }
        .padding(.top, 40)
    }
}

/// Sized by its content rather than by a fixed rectangle. The old version drew the text
/// over a Rectangle of a hardcoded width per string — 190pt for 警報取消, 150 for 錯誤報 —
/// so any longer or localized wording spilled outside its own background.
private struct SpecialCaseBanner: View {
    let facet: ReportFacet
    let arrivalTime: Date

    /// Flashing is motion, and indefinite flashing is the kind of thing users turn Reduce
    /// Motion on to escape. Honoured rather than overridden — the colour and the wording
    /// already carry the meaning without it.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLit = true


    /// Softer than the 0.15 those two use: a small marker at 0.15 reads as a pulse, a
    /// full-width banner at 0.15 strobes.
    private static let dimOpacity: Double = 0.25

    var body: some View {
        Text(facet.label)
            .font(.system(size: UIScreen.isZoomed ? 26 : 32).bold())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(facet.badge.foreground)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(facet.badge.background)
            )
            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.18), radius: 8, y: 2)
            .opacity(isLit ? 1 : Self.dimOpacity)
            .onReceive(Timer.publish(every: AlertBlink.tick, on: .main, in: .common).autoconnect()) { _ in
                guard !reduceMotion else {
                    isLit = true
                    return
                }
                isLit = AlertBlink.isLit(arrivalTime: arrivalTime)
            }
    }
}

