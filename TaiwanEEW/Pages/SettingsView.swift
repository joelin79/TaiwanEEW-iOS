//
//  SettingsView.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/7/8.
//
///  2026/08/24 Changelog - Albert
///   - Added most missing localizations for this tab, including the cities ones 新增大部分字串的英文及日文翻譯，包括縣市城鎮的翻譯
///

import SwiftUI
import UserNotifications
import StoreKit

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("subscribedCityIndex") var subscribedCityIndex: Int = 0
    @AppStorage("subscribedDistrictIndex") var subscribedDistrictIndex: Int = 0
    @AppStorage("HRSelection") var HRSelection: TimeRange = .year
    @AppStorage("notifySelection") var notifySelection: NotifyThreshold = .eg3
    @AppStorage("locationNarrationEnabled") var locationNarrationEnabled: Bool = true
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

    // MARK: - Notification permission presentation

    /// True when notifications are denied or a sub-permission is off - i.e. the settings
    /// link is a fix rather than a shortcut. False until the async read completes.
    private var notificationNeedsAttention: Bool {
        guard let settings = notificationSettings else { return false }
        return !notificationIssues(settings).isEmpty
    }

    private func refreshNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationSettings = settings
            }
        }
    }

    private func isNotificationAllowed(_ s: UNNotificationSettings) -> Bool {
        s.authorizationStatus == .authorized
            || s.authorizationStatus == .provisional
            || s.authorizationStatus == .ephemeral
    }

    /// Sub-permissions that are off while notifications are otherwise allowed. Each one
    /// degrades delivery in a way the user would not otherwise see until an earthquake.
    private func notificationIssues(_ s: UNNotificationSettings) -> [String] {
        guard isNotificationAllowed(s) else {
            return ["notification-issue-unallowed".localized]
        }
        var issues: [String] = []
        if s.criticalAlertSetting == .disabled {
            issues.append("notification-issue-critical".localized)
        }
        if s.timeSensitiveSetting == .disabled {
            issues.append("notification-issue-time-sensitive".localized)
        }
        return issues
    }

    /// Describes the iOS permission, not whether alerts are actually being delivered -
    /// the user may separately have set the intensity threshold to off, and calling that
    /// "啟用" would read as a contradiction.
    private func notificationHeadline(_ s: UNNotificationSettings) -> String {
        switch s.authorizationStatus {
        case .denied:        return "notification-issue-unallowed-headline".localized
        case .notDetermined: return "notification-issue-notsetup".localized
        default:             return notificationIssues(s).isEmpty ? "notification-perm-ok".localized : "notification-perm-incomplete".localized
        }
    }

    private func notificationStatusIcon(_ s: UNNotificationSettings) -> String {
        switch s.authorizationStatus {
        case .denied:        return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        default:             return notificationIssues(s).isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        }
    }

    private func notificationStatusColor(_ s: UNNotificationSettings) -> Color {
        switch s.authorizationStatus {
        case .denied:        return .red
        case .notDetermined: return .orange
        default:             return notificationIssues(s).isEmpty ? .green : .orange
        }
    }

    // MARK: - Auto-location status presentation
    // Each authorization state fails differently, so each one says what is actually true:
    // "While Using" cannot update in the background, and denied/notDetermined cannot read
    // location at all - none of which is "enabled".

    private var canFetchLocation: Bool {
        locationManager.authorizationStatus == .authorizedAlways
            || locationManager.authorizationStatus == .authorizedWhenInUse
    }

    /// Auto-location is only actually driving the subscribed district when the toggle is on
    /// *and* permission allows reading location. Manual selection is locked on this rather
    /// than on the toggle alone, so a user whose permission is denied is never left with
    /// neither automatic nor manual district selection.
    private var isAutoLocationActive: Bool {
        locationManager.isAutoLocationEnabled && canFetchLocation
    }

    private var autoLocationHeadline: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:    return "autoloc-ok".localized
        case .authorizedWhenInUse: return "autoloc-issue-fore-only".localized
        case .denied, .restricted: return "autoloc-issue-denied".localized
        case .notDetermined:       return "autoloc-issue-notsetup".localized
        @unknown default:          return "autoloc-issue-unknown".localized
        }
    }

    private var autoLocationStatusDetail: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:    return "autoloc-ok-always".localized
        case .authorizedWhenInUse: return "autoloc-foreground-only-detail".localized
        case .denied:              return "autoloc-denied-detail".localized
        case .restricted:          return "autoloc-restricted-detail".localized
        case .notDetermined:       return "autoloc-notsetup-detail".localized
        @unknown default:          return "autoloc-unknown-detail".localized
        }
    }

    private var autoLocationStatusIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:    return "checkmark.circle.fill"
        case .authorizedWhenInUse: return "exclamationmark.triangle.fill"
        case .denied, .restricted: return "xmark.circle.fill"
        case .notDetermined:       return "questionmark.circle.fill"
        @unknown default:          return "questionmark.circle.fill"
        }
    }

    private var autoLocationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:    return .green
        case .authorizedWhenInUse: return .orange
        case .denied, .restricted: return .red
        case .notDetermined:       return .orange
        @unknown default:          return .orange
        }
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
                footer: Text("開啟後，自動定位每次切換通知區域時會發送提示通知，方便測試背景更新是否運作。此區塊僅在開發與 TestFlight 版本顯示。"))
            {
                Toggle("自動定位切換通知", isOn: $locationNarrationEnabled)

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
                    Text("donate-eew-string")
                        .font(.title3.bold())
                        .opacity(0.9)

                    Text("donate-eew-detail-string")
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
                    Text("autoloc")
                },
            footer: Text("autoloc-footer"))
        {
            Toggle("autoloc-enable-toggle", isOn: $locationManager.isAutoLocationEnabled)
                .onChange(of: locationManager.isAutoLocationEnabled) { isEnabled in
                    if isEnabled {
                        locationManager.updateLocationManually()
                    }
                }
            
            if locationManager.isAutoLocationEnabled {
                HStack {
                    Image(systemName: autoLocationStatusIcon)
                        .foregroundColor(autoLocationStatusColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(autoLocationHeadline)
                            .font(.headline)
                        if let location = locationManager.currentLocation {
                            let (cityIndex, districtIndex, distance) = locationManager.findClosestDistrict(to: location.coordinate)
                            let districtName = Location.cities[cityIndex].district[districtIndex].districtName
                            let distanceKm = String(format: "%.1f", distance / 1000)
                            HStack {
                                Text("最近震度參考點：\(districtName)") // localized as Text objects utilize catalog automatically
                                    .font(.caption)
                                Text("(\(distanceKm) 公里)") // again, localized automatically and implicitly; set up the interpolated keys in string catalog as %lf
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if canFetchLocation {
                            // Only claim we are working on it when permission actually allows it;
                            // otherwise the status line below explains what is blocking.
                            Text("loc-acquire")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(autoLocationStatusDetail)
                            .font(.caption)
                            .foregroundColor(locationManager.authorizationStatus == .authorizedAlways ? .secondary : autoLocationStatusColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                
                // When permission is the blocker, a manual refresh cannot help - send the
                // user where the problem is actually fixable instead.
                switch locationManager.authorizationStatus {
                case .denied, .restricted:
                    Button("open-app-settings-for-loc-denied".localized) {
                        openAppSettings()
                    }
                    .foregroundColor(.blue)
                case .authorizedWhenInUse:
                    Button("open-app-settings-for-loc-fore".localized) {
                        openAppSettings()
                    }
                    .foregroundColor(.blue)
                case .notDetermined:
                    // updateLocationManually() requests permission in this state rather
                    // than refreshing, so label it for what it actually does.
                    Button("open-app-settings-for-loc-notsetup".localized) {
                        locationManager.updateLocationManually()
                    }
                    .foregroundColor(.blue)
                default:
                    // Manual refresh hidden: with permission granted, location already
                    // updates on its own, so the button only invited confusion.
//                    Button("手動更新位置") {
//                        locationManager.updateLocationManually()
//                    }
//                    .foregroundColor(.blue)
                    EmptyView()
                }
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
            footer: isAutoLocationActive ? Text("auto-cant-manual-footer") : Text("notice1-string"))
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
                            Text("north-region")
                        }
                        Section {
                            ForEach(6..<11, id: \.self){ cityIndex in
                                Text(Location.cities[cityIndex].getDisplayName())
                            }
                        } header: {
                            Text("central-region")
                        }
                        Section {
                            ForEach(11..<16, id: \.self){ cityIndex in
                                Text(Location.cities[cityIndex].getDisplayName())
                            }
                        } header: {
                            Text("south-region")
                        }
                        Section {
                            ForEach(16..<19, id: \.self){ cityIndex in
                                Text(Location.cities[cityIndex].getDisplayName())
                            }
                        } header: {
                            Text("east-region")
                        }
                        Section {
                            ForEach(19..<Location.cities.count, id: \.self){ cityIndex in
                                Text(Location.cities[cityIndex].getDisplayName())
                            }
                        } header: {
                            Text("island-regions")
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
            if let settings = notificationSettings {
                HStack {
                    Image(systemName: notificationStatusIcon(settings))
                        .foregroundColor(notificationStatusColor(settings))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notificationHeadline(settings))
                            .font(.headline)
                        ForEach(notificationIssues(settings), id: \.self) { issue in
                            Text(issue)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            List {
                Picker("notify-threshold-string", selection: $notifySelection){
                    ForEach(NotifyThreshold.allCases){ notifyThreshold in
                        Text(notifyThreshold.getDisplayName())
                    }
                }
            }
            Link(destination: UIApplication.appNotificationSettingsURL!) {
                HStack{
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundStyle(.red)
                    // Reads as a fix-this action while something is wrong, and as a plain
                    // settings shortcut once everything is in order.
                    Text(notificationNeedsAttention ? "critnotif-fix" : "critnotif-set")
                        .foregroundStyle(.blue)
                }
            }
        }.onChange(of: notifySelection) { value in
            onNotifyThresholdChanged?(value)
        }
        .onAppear { refreshNotificationSettings() }
        // Re-read on return from iOS Settings, where these toggles actually live.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationSettings()
        }
    }
    
    private var linksSection: some View {
        Section(
            header:
                HStack{
                    Image(systemName: "questionmark.bubble.fill")
                    Text("feedback-header")
                })
        {
            Link(destination: AppLinks.discord){
                HStack(alignment: .center) {
                    Image("discord-mark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        
                    Text("discord").frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.blue)
                    Text("discord-detail")
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
                        Text("threads").frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.blue)
                    }
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
                Text("林子祐製作、版權所有")
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
                    Text("lang-loc-settings")
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
                Text("copied")
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
                    .navigationTitle("tab-set-header".localized)
                    .toolbarBackground(Color(.clear), for: .navigationBar)
                    .modifier(NavigationModifier(selectedCityIndex: $subscribedCityIndex, selectedDistrictIndex: $subscribedDistrictIndex, locationManager: locationManager))
                }
            }
            else {
                NavigationView {
                    Form {
                        formContent
                    }
                    .navigationTitle("tab-set-header".localized)
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
//        SettingsView().environment(\.locale, Locale.init(identifier: "zh-Hant"))
        SettingsView().environment(\.locale, Locale.init(identifier: "en"))
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
