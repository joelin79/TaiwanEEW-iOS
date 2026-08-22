//
//  SettingsView.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/7/8.
//

import SwiftUI
import UserNotifications
import StoreKit

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("subscribedCityIndex") var subscribedCityIndex: Int = 0
    @AppStorage("subscribedDistrictIndex") var subscribedDistrictIndex: Int = 0
    @AppStorage("HRSelection") var HRSelection: TimeRange = .year
    @AppStorage("notifySelection") var notifySelection: NotifyThreshold = .eg3
    @AppStorage("locationNarrationEnabled") var locationNarrationEnabled: Bool = false
    @AppStorage("useTestEEWData") var useTestEEWData: Bool = false
    @AppStorage("showMapFramingDebug") var showMapFramingDebug: Bool = false
    @AppStorage(AwayFramingPreference.storageKey) var awayFraming = AwayFramingPreference.taiwan
    @AppStorage(CollapsedFramingPreference.storageKey) var collapsedFraming = CollapsedFramingPreference.taiwanOnly
    @State private var confirmingTestEEWData = false
    @State private var selectedAlertOption = 0
    @State private var showSheet = false
    @State private var copiedItem: String? = nil
    @State private var subscribedTopics: [String] = []
    @State private var notificationSettings: UNNotificationSettings? = nil
    @State private var storefrontCountry: String = "…"
    @StateObject private var locationManager = LocationManager.shared
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    var onHistoryRangeChanged: ((TimeRange) -> Void)?
    var onSubscribedLocChanged: (([Int]) -> Void)?
    var onNotifyThresholdChanged: ((NotifyThreshold) -> Void)?
//    var currentSubscribedTopics: String {
//        // Step 1: Filter the dictionary to keep only the true values
//        let trueKeys = FCMManager.currentSubscribedTopics.filter { $0.value }.map { $0.key }
//        
//        // Step 2: Join the keys into a single string separated by commas (or any delimiter you prefer)
//        return trueKeys.joined(separator: ", ")
//    }
    /*
     1. Selection in menu triggers the onChange
     2. onChange passes the new val into the onHistoryRangeChanged closure
     3. The closure, defined in @main, updates the var accessable between views
     */
    
    
    private var formContent: some View {
        Group {
            donationSection
            autoLocationSection
            locationSelectionSection
            alertThresholdSection
            mapFramingSection
            linksSection
            aboutSection
            reminderSection
            diagnosticsSection
            debugSection
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Permission presentation
    //
    // Both permissions are described by shared models so this screen and onboarding cannot
    // drift apart in wording, icon or colour. See NotificationPermissionStatus and
    // LocationPermissionStatus.

    private var notificationStatus: NotificationPermissionStatus {
        NotificationPermissionStatus(settings: notificationSettings)
    }

    private var locationPermission: LocationPermissionStatus {
        LocationPermissionStatus(status: locationManager.authorizationStatus)
    }

    private func refreshNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationSettings = settings
            }
        }
    }

    /// Auto-location is only actually driving the subscribed district when the toggle is on
    /// *and* permission allows reading location. Manual selection is locked on this rather
    /// than on the toggle alone, so a user whose permission is denied is never left with
    /// neither automatic nor manual district selection.
    private var isAutoLocationActive: Bool {
        locationManager.isAutoLocationEnabled && locationPermission.canFetchLocation
    }

    /// Debug/TestFlight only - never rendered for App Store users.
    @ViewBuilder
    private var diagnosticsSection: some View {
        if LocationManager.isDiagnosticsAvailable {
            Section(
                header:
                    HStack {
                        Image(systemName: "ladybug.fill")
                        Text("除錯 Debug")
                    },
                footer: Text("此區塊僅在開發與 TestFlight 版本顯示。"))
            {
                // Turning this on is the risky direction, so only that way round asks;
                // switching back to live data needs no confirmation.
                Toggle("顯示測試地震資料", isOn: Binding(
                    get: { useTestEEWData },
                    set: { wants in
                        if wants {
                            confirmingTestEEWData = true
                        } else {
                            useTestEEWData = false
                        }
                    }
                ))

                if useTestEEWData {
                    Label("目前顯示 EEW-test 測試資料，不會顯示真實地震", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Harmless either way, so no confirmation — it only draws over the map.
                Toggle("顯示地圖取景範圍", isOn: $showMapFramingDebug)

                if showMapFramingDebug {
                    Text("在地圖上畫出取景範圍、目前位置與震央的連線，以及兩點的中心。中心點不會落在畫面正中央，差距即為邊界留白與下方卡片所佔的空間。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DisclosureGroup("已訂閱主題 (\(subscribedTopics.count))") {
                    if subscribedTopics.isEmpty {
                        Text("目前沒有訂閱任何主題")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            if !locationTopics.isEmpty {
                                Text(locationTopics.joined(separator: " "))
                            }
                            if !otherTopics.isEmpty {
                                Text(otherTopics.joined(separator: " "))
                            }
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                        Button(copiedItem == "topics" ? "已複製" : "拷貝全部") {
                            copyToPasteboard(subscribedTopics.joined(separator: "\n"), label: "topics")
                        }
                        .font(.caption)
                        .foregroundStyle(copiedItem == "topics" ? .green : .blue)
                    }
                }
            }
            // currentSubscribedTopics lives in UserDefaults and is written from the AWS
            // callbacks, so watching UserDefaults keeps this list live as subscriptions
            // change rather than only refreshing when the view happens to redraw.
            .onAppear { refreshSubscribedTopics() }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: UserDefaults.didChangeNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                refreshSubscribedTopics()
            }
            .alert("顯示測試地震資料？", isPresented: $confirmingTestEEWData) {
                Button("取消", role: .cancel) { }
                Button("啟用測試資料", role: .destructive) { useTestEEWData = true }
            } message: {
                Text("即時警報將改為讀取 EEW-test 測試資料，期間不會顯示真實地震。推播通知不受影響，仍會照常送達。測試結束後請記得關閉。")
            }
        }
    }

    /// District alert topics, e.g. 10501eg3
    private var locationTopics: [String] {
        subscribedTopics.filter { $0.range(of: #"^\d{5}eg\d$"#, options: .regularExpression) != nil }
    }

    /// Everything else - version topics, off, and anything unrecognised.
    private var otherTopics: [String] {
        subscribedTopics.filter { $0.range(of: #"^\d{5}eg\d$"#, options: .regularExpression) == nil }
    }

    /// Local record of AWS SNS subscriptions, which is what the app believes it is
    /// subscribed to - verify against AWS itself when a mismatch is suspected.
    private func refreshSubscribedTopics() {
        subscribedTopics = NotificationManager.AWSManager.currentSubscribedTopics.keys.sorted()
    }
    
    private var donationSection: some View {
        ZStack {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .overlay(
                        ZStack {
                            Image(colorScheme == .dark ? "noise2" : "noise1")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                            
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 2)
                                .opacity(0.8)
                        }
                    )
            }

            HStack(spacing: 0){
                Spacer()
                Image(systemName: "giftcard")
                    .font(.system(size: 32))
                Spacer()
                VStack(alignment: .leading) {
                    Text("應援台灣地震速報")
                        .font(.title3.bold())
                        .opacity(0.9)

                    Text("您可以透過小額贊助減輕開發者花費負擔，\n讓應用程式永續經營！")
                        .font(.caption)
                        .opacity(0.9)
                }
                .padding(.vertical, 20)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowInsets(EdgeInsets())
        .background(Color(UIColor.systemGroupedBackground))
        .onTapGesture {
            showSheet.toggle()
        }
    }
    
    private var autoLocationSection: some View {
        Section(
            header:
                HStack{
                    Image(systemName: "location.fill")
                    Text("自動定位")
                },
            footer: Text("啟用後將自動根據您的位置選擇最近的地震通知區域(距離最近的震度參考點未必在您所在的區域界內)。需要「永遠」位置權限以啟用背景更新。"))
        {
            Toggle("啟用自動定位", isOn: $locationManager.isAutoLocationEnabled)
                .onChange(of: locationManager.isAutoLocationEnabled) { isEnabled in
                    if isEnabled {
                        locationManager.updateLocationManually()
                    }
                }
            
            if locationManager.isAutoLocationEnabled {
                AutoLocationStatusRow(permission: locationPermission,
                                      locationManager: locationManager)

                // When permission is the blocker, a manual refresh cannot help - send the
                // user where the problem is actually fixable instead.
                LocationFixButton(
                    status: locationPermission,
                    requestPermission: { locationManager.updateLocationManually() },
                    openSettings: { openAppSettings() }
                )
            }
        }
    }
    
    private var locationSelectionSection: some View {
        Section(
            header:
                HStack{
                    Image(systemName: "mappin.circle.fill")
                    Text("alerts-pref-string")
                },
            footer: isAutoLocationActive ? Text("自動定位運作中，無法手動選擇地區") : Text("notice1-string"))
        {
            if isAutoLocationActive {
                HStack {
                    Text("location-pref-string")
                    Spacer()
                    Text("\(Location.cities[subscribedCityIndex].getDisplayName().toString()) \(String(Location.cities[subscribedCityIndex].district[subscribedDistrictIndex].districtName.dropFirst(3)))")
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    Picker("location-pref-string", selection: $subscribedCityIndex){
                        Section {
                            ForEach(0..<6, id: \.self){ cityIndex in
                                Text(Location.cities[cityIndex].getDisplayName())
                            }
                        } header: {
                            Text("北部")
                        }
                        Section {
                            ForEach(6..<11, id: \.self){ cityIndex in
                                Text(Location.cities[cityIndex].getDisplayName())
                            }
                        } header: {
                            Text("中部")
                        }
                        Section {
                            ForEach(11..<16, id: \.self){ cityIndex in
                                Text(Location.cities[cityIndex].getDisplayName())
                            }
                        } header: {
                            Text("南部")
                        }
                        Section {
                            ForEach(16..<19, id: \.self){ cityIndex in
                                Text(Location.cities[cityIndex].getDisplayName())
                            }
                        } header: {
                            Text("東部")
                        }
                        Section {
                            ForEach(19..<Location.cities.count, id: \.self){ cityIndex in
                                Text(Location.cities[cityIndex].getDisplayName())
                            }
                        } header: {
                            Text("離島")
                        }
                    }
                    .onChange(of: subscribedCityIndex) { value in
                        subscribedDistrictIndex = 0
                        if !isAutoLocationActive {
                            onSubscribedLocChanged?([value, 0])
                        }
                    }
                    
                    Picker("district-pref-string", selection: $subscribedDistrictIndex){
                        ForEach(0..<Location.cities[subscribedCityIndex].district.count, id: \.self){ districtIndex in
                            Text(String(Location.cities[subscribedCityIndex].district[districtIndex].districtName.dropFirst(3)))
                        }
                    }
                    .onChange(of: subscribedDistrictIndex) { value in
                        if !isAutoLocationActive {
                            onSubscribedLocChanged?([subscribedCityIndex, value])
                        }
                    }
                }
            }
        }
    }
    
    private var alertThresholdSection: some View {
        Section(
            header:
                HStack{
                    Image(systemName: "app.badge")
                    Text("notify-pref-string")
                },
            footer: Text("notify-force-string"))
        {
            // Critical and time-sensitive alerts are separate iOS toggles that silently
            // downgrade delivery when off, so surface them here rather than leaving the
            // user to discover it during an earthquake.
            if notificationSettings != nil {
                NotificationStatusRow(status: notificationStatus)
            }

            List {
                Picker("notify-threshold-string", selection: $notifySelection){
                    ForEach(NotifyThreshold.allCases){ notifyThreshold in
                        Text(notifyThreshold.getDisplayName())
                    }
                }
            }
            NotificationSettingsLink(needsAttention: notificationStatus.needsAttention)
        }.onChange(of: notifySelection) { value in
            onNotifyThresholdChanged?(value)
        }
        .onAppear { refreshNotificationSettings() }
        // Re-read on return from iOS Settings, where these toggles actually live.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationSettings()
        }
    }
    
    /// The alert card's two positions frame the map differently — expanded is
    /// first-person, collapsed is an island overview — so each gets its own choice. The
    /// expanded one only applies when the user's position cannot anchor the view, since
    /// otherwise it always frames you together with the epicenter.
    private var mapFramingSection: some View {
        Section(
            header:
                HStack {
                    Image(systemName: "map")
                    Text("地圖取景")
                },
            footer: Text("展開時若已取得你在台灣的位置，一律同時顯示你與震央。"))
        {
            Picker("無法定位或不在台灣時", selection: $awayFraming) {
                ForEach(AwayFramingPreference.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            Picker("收合卡片時", selection: $collapsedFraming) {
                ForEach(CollapsedFramingPreference.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        }
    }

    private var linksSection: some View {
        Section(
            header:
                HStack{
                    Image(systemName: "questionmark.bubble.fill")
                    Text("產品公告／意見回饋")
                })
        {
            Link(destination: AppLinks.discord){
                HStack(alignment: .center) {
                    Image("discord-mark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        
                    Text("Discord 官方社群").frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.blue)
                    Text("意見回饋主要管道")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            Link(destination: AppLinks.threads){
                HStack(alignment: .center){
                    HStack() {
                        Image("threads-mark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("Threads 官方帳號").frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.blue)
                    }
                }
            }
            Link(destination: AppLinks.github){
                HStack(alignment: .center) {
                    Image("github-mark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("GitHub 開源專案").frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    private var aboutSection: some View {
        Section(
            header:
                HStack{
                    Image(systemName: "info.circle.fill")
                    Text("about-title-string")
                })
        {
            VStack(alignment: .center){
                Image("Icon")
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .padding(.top)
                Text("台灣地震速報")
                    .font(.system(size: 24))
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                Text("版本 \(appVersion ?? "n/a") (\(buildNumber ?? "n/a"))")
                    .font(.system(size: 18).monospaced())
                Text("林子祐製作、版權所有 ")
                    .font(.system(size: 18))
                HStack{
                    Text("中央氣象署合作對象")
                        .font(.system(size: 18))
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 18))
                }
                .padding(.bottom)
            }.frame(width: 1000)
            
            Link(destination: AppLinks.termsOfService) {
                Text("服務條款").frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.blue)
            }
            
            NavigationLink {
                InformationView()
                    .navigationTitle("information-title-string")
            } label: {
                Text("information-title-string")
            }
            
            NavigationLink {
                TermsOfUseView()
                    .navigationTitle("term-title-string")
            } label: {
                Text("term-title-string")
            }
            
            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                HStack{
                    Image(systemName: "globe")
                        .foregroundStyle(.indigo)
                    Text("語言、位置權限設定")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    private var reminderSection: some View {
        VStack(alignment: .leading) {
            Text("reminder-title-string")
                .font(.headline)
                .padding(.bottom, 2)
                .foregroundColor(.red)
            Text("reminder-string")
        }
    }
    
    private var debugSection: some View {
        Section{
            copyableRow(title: "APNs", value: UserDefaults.standard.string(forKey: "deviceTokenForSNS") ?? "nil")
            copyableRow(title: "ARN", value: UserDefaults.standard.string(forKey: "endpointArnSuffixForSNS") ?? "nil")
            // App Store storefront the device is on. Explains IAP currency: a device on the
            // US storefront (or signed into a US sandbox account) shows USD even in Taiwan.
            copyableRow(title: "Storefront", value: storefrontCountry)
        } header: {
            Text("可點擊拷貝")
        }
        .task { await loadStorefront() }
    }

    private func loadStorefront() async {
        if let sf = await Storefront.current {
            storefrontCountry = sf.countryCode
        } else {
            storefrontCountry = "unavailable"
        }
    }

    private func copyableRow(title: String, value: String) -> some View {
        HStack{
            Text(title)
            Spacer()
            // Both labels stay in the layout and cross-fade, so the row keeps the taller
            // value's height instead of collapsing when the short 已複製 replaces it.
            ZStack(alignment: .trailing) {
                Text(value)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.trailing)
                    .opacity(copiedItem == title ? 0 : 1)
                Text("已複製")
                    .foregroundStyle(.green)
                    .opacity(copiedItem == title ? 1 : 0)
            }
        }
        // Without this the gap between label and value does not register taps.
        .contentShape(Rectangle())
        .onTapGesture {
            copyToPasteboard(value, label: title)
        }
    }

    private func copyToPasteboard(_ value: String, label: String) {
        UIPasteboard.general.string = value
        withAnimation { copiedItem = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Only clear if nothing else has been copied since.
            if copiedItem == label {
                withAnimation { copiedItem = nil }
            }
        }
    }

    var body: some View {
        VStack {
            if #available(iOS 16, *){
                NavigationStack {
                    Form {
                        formContent
                    }
                    .navigationTitle("設定 Settings")
                    .toolbarBackground(Color(.clear), for: .navigationBar)
                    .modifier(NavigationModifier(selectedCityIndex: $subscribedCityIndex, selectedDistrictIndex: $subscribedDistrictIndex, locationManager: locationManager))
                }
            }
            else {
                NavigationView {
                    Form {
                        formContent
                    }
                    .navigationTitle("設定 Settings")
                    .modifier(NavigationModifier(selectedCityIndex: $subscribedCityIndex, selectedDistrictIndex: $subscribedDistrictIndex, locationManager: locationManager))
                }
            }
        }
        .fullScreenCover(isPresented: $showSheet, content: {
            DonateView()
        })
    }
}

struct NavigationModifier: ViewModifier {
    @Binding var selectedCityIndex: Int
    @Binding var selectedDistrictIndex: Int
    @ObservedObject var locationManager: LocationManager
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Ensure UI reflects current stored values when view appears
                // Auto-location changes are now handled by the main app callback
                let storedCity = UserDefaults.standard.integer(forKey: "subscribedCityIndex")
                let storedDistrict = UserDefaults.standard.integer(forKey: "subscribedDistrictIndex")
                if storedCity < Location.cities.count,
                   storedDistrict < Location.cities[storedCity].district.count {
                    selectedCityIndex = storedCity
                    selectedDistrictIndex = storedDistrict
                }
            }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environment(\.locale, Locale.init(identifier: "zh-Hant"))
        //SettingsView().environment(\.locale, Locale.init(identifier: "en"))
        //SettingsView().environment(\.locale, Locale.init(identifier: "ja"))
    }
}

extension UIApplication {
    private static let notificationSettingsURLString: String? = {
        if #available(iOS 16, *){
            return UIApplication.openNotificationSettingsURLString
        }
        if #available(iOS 15.4, *){
            return UIApplicationOpenNotificationSettingsURLString
        }
        
        return nil
    }()
    
    static let appNotificationSettingsURL = URL(string: notificationSettingsURLString ?? "")
}
