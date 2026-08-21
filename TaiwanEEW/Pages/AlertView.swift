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
            AlertMapView(eventManager: eventManager, cardObscuredHeight: cardObscuredHeight)
                .ignoresSafeArea()
            ErrorBanner(msgType: msgType, status: status)
            
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
            AlertMapView(eventManager: eventManager, cardObscuredHeight: 0)
                .ignoresSafeArea()
            ErrorBanner(msgType: msgType, status: status)
            
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

struct ErrorBanner: View {
    var msgType: String?
    var status: String?
    
    var body: some View {
        VStack {
            if(msgType?.lowercased() == "cancel"){
                Text("警報取消 \nCanceled")
                    .font(.system(size: 40).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .background(Rectangle().frame(width: 190, height: 120).foregroundStyle(.brown))
                    .frame(maxWidth: .infinity)
            } else if (msgType?.lowercased() == "error"){
                Text("錯誤報 \nError")
                    .font(.system(size: 40).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .background(Rectangle().frame(width: 150, height: 120).foregroundStyle(.brown))
                    .frame(maxWidth: .infinity)
            }
            
            if(status?.lowercased() == "exercise"){
                Text("演練 \nDrill")
                    .font(.system(size: 50).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .background(Rectangle().frame(width: 120, height: 120).foregroundStyle(.pink))
                    .frame(maxWidth: .infinity)
            } else if (status?.lowercased() == "test" && !TaiwanEEWApp.DEBUG){
                Text("測試 \nTest")
                    .font(.system(size: 50).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .background(Rectangle().frame(width: 120, height: 120).foregroundStyle(.green))
                    .frame(maxWidth: .infinity)
            } else if (status?.lowercased() == "system"){
                Text("系統 \nSystem")
                    .font(.system(size: 50).bold())
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
                    .background(Rectangle().frame(width: 120, height: 120).foregroundStyle(.pink))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 40)
    }
}
