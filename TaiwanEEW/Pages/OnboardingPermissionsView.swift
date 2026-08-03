//
//  OnboardingPermissionsView.swift
//  TaiwanEEW
//
//  Second onboarding page. Both asks live here because both are permissions:
//  notifications on top (without them the app cannot warn you at all), auto-location
//  below (it decides *which* region's warnings you get).
//
//  Auto-location is the encouraged default — it keeps the alert region correct as the
//  user moves. Manual district selection is deliberately NOT offered up front; it only
//  replaces the auto block when location permission is denied, so a denied user still
//  ends up with a region rather than silently defaulting to the first district in the
//  list (which is what shipped before this screen existed).
//

import SwiftUI
import UserNotifications

struct OnboardingPermissionsView: View {
    var onDone: () -> Void

    @AppStorage("subscribedCityIndex") private var subscribedCityIndex: Int = 0
    @AppStorage("subscribedDistrictIndex") private var subscribedDistrictIndex: Int = 0
    @StateObject private var locationManager = LocationManager.shared

    @State private var notificationsGranted = false
    @State private var notificationsAsked = false

    private var permission: LocationPermissionStatus {
        LocationPermissionStatus(status: locationManager.authorizationStatus)
    }

    /// Location is unusable, so fall back to letting the user pick a region by hand.
    private var needsManualRegion: Bool { permission.isBlocked }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                notificationSection

                if needsManualRegion {
                    manualRegionSection
                } else {
                    autoLocationSection
                }
            }

            continueButton
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .navigationTitle("開始設定")
        .navigationBarTitleDisplayMode(.large)
        .animation(.default, value: needsManualRegion)
        .onAppear { refreshNotificationStatus() }
        // Permission can change in iOS Settings while the app is backgrounded.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationStatus()
        }
    }

    // MARK: - Notifications (top)

    private var notificationSection: some View {
        Section(
            header: Label("地震通知", systemImage: "bell.badge.fill"),
            footer: Text(notificationsGranted
                         ? "已允許通知，地震發生時會立即提醒您。"
                         : "地震速報透過推播在第一時間提醒您。未允許通知將無法收到地震預警。")
        ) {
            Toggle("接收地震預警", isOn: Binding(
                get: { notificationsGranted },
                set: { wants in
                    // Only the first tap can prompt; iOS ignores later requests, so send
                    // the user to Settings once the choice has been made.
                    if wants && !notificationsAsked {
                        requestNotifications()
                    } else if wants {
                        openAppSettings()
                    }
                }
            ))
            .disabled(notificationsGranted)

            if notificationsAsked && !notificationsGranted {
                Label {
                    Text("通知權限已關閉，可稍後至「設定」重新開啟。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Button("前往設定") { openAppSettings() }
            }
        }
    }

    // MARK: - Auto-location (bottom, the encouraged default)

    private var autoLocationSection: some View {
        Section(
            header: Label("自動定位", systemImage: "location.fill"),
            footer: Text("自動依您的位置選擇最近的通知區域，移動時也會自動更新。之後可在「設定」中更改。")
        ) {
            Toggle("啟用自動定位", isOn: $locationManager.isAutoLocationEnabled)
                .onChange(of: locationManager.isAutoLocationEnabled) { isEnabled in
                    if isEnabled { locationManager.updateLocationManually() }
                }

            if locationManager.isAutoLocationEnabled {
                HStack {
                    Image(systemName: permission.icon)
                        .foregroundStyle(permission.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(permission.headline)
                            .font(.headline)
                        if let location = locationManager.currentLocation {
                            let (cityIndex, districtIndex, _) = locationManager.findClosestDistrict(to: location.coordinate)
                            Text("通知區域：\(Location.cities[cityIndex].district[districtIndex].districtName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if permission.canFetchLocation {
                            Text("正在取得位置...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Manual region (only when location is denied)

    private var manualRegionSection: some View {
        Section(
            header: Label("選擇通知區域", systemImage: "mappin.and.ellipse"),
            footer: Text("可稍後至「設定」重新開啟位置權限，改用自動定位。")
        ) {
            Label {
                Text("無法取得位置權限，請手動選擇您所在的區域。")
                    .font(.caption)
                    .foregroundStyle(.red)
            } icon: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            Picker("縣市", selection: $subscribedCityIndex) {
                ForEach(0..<Location.cities.count, id: \.self) { i in
                    Text(Location.cities[i].getDisplayName()).tag(i)
                }
            }
            .onChange(of: subscribedCityIndex) { _ in subscribedDistrictIndex = 0 }

            Picker("地區", selection: $subscribedDistrictIndex) {
                ForEach(0..<Location.cities[subscribedCityIndex].district.count, id: \.self) { i in
                    Text(String(Location.cities[subscribedCityIndex].district[i].districtName.dropFirst(3))).tag(i)
                }
            }

            Button("前往設定開啟位置權限") { openAppSettings() }
        }
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button(action: finish) {
            Text("開始使用")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .background(continueBackground)
    }

    @ViewBuilder
    private var continueBackground: some View {
        if #available(iOS 26.0, *) {
            Color.accentColor
                .glassEffect(.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: 14))
        } else {
            RoundedRectangle(cornerRadius: 14).fill(Color.accentColor)
        }
    }

    // MARK: - Actions

    private func finish() {
        // Commit the chosen region. Subscription is gated until this runs, so a user who
        // never reaches here is not silently subscribed to the default district.
        NotificationManager.setNotifyMode(
            cityIndex: subscribedCityIndex,
            districtIndex: subscribedDistrictIndex,
            threshold: NotifyThreshold(rawValue: UserDefaults.standard.string(forKey: "notifyThreshold") ?? "eg3") ?? .eg3
        )
        onDone()
    }

    private func requestNotifications() {
        notificationsAsked = true
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound, .criticalAlert]
        ) { granted, _ in
            DispatchQueue.main.async {
                notificationsGranted = granted
                if granted { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsGranted = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                    || settings.authorizationStatus == .ephemeral
                if settings.authorizationStatus != .notDetermined { notificationsAsked = true }
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
