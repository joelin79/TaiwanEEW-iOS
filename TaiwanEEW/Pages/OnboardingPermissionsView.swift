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

    // The full settings object rather than a granted/denied flag: the status row reports on
    // the critical and time-sensitive sub-permissions too, exactly as Settings does.
    @State private var notificationSettings: UNNotificationSettings? = nil

    private var notificationStatus: NotificationPermissionStatus {
        NotificationPermissionStatus(settings: notificationSettings)
    }

    private var permission: LocationPermissionStatus {
        LocationPermissionStatus(status: locationManager.authorizationStatus)
    }

    /// Location is unusable, so fall back to letting the user pick a region by hand.
    private var needsManualRegion: Bool { permission.isBlocked }

    // Layout mirrors FirstLaunchView so the two onboarding screens feel like one flow:
    // same max width, same icon/title sizes and position, same full-width button at the
    // bottom with the same vertical padding.
    var body: some View {
        GeometryReader { geometry in
            let maxWidth = min(geometry.size.width, 650)

            VStack {
                icon
                title

                ScrollView {
                    VStack(spacing: 20) {
                        notificationCard
                        if needsManualRegion {
                            manualRegionCard
                        } else {
                            autoLocationCard
                        }
                    }
                    .padding(.top, 24)
                }

                continueButton
            }
            .frame(maxWidth: maxWidth, maxHeight: .infinity)
            .frame(maxWidth: .infinity)     // center the content
            .padding(.horizontal, 20)
            .padding(.vertical, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.background))
        .transition(.move(edge: .bottom))
        .animation(.default, value: needsManualRegion)
        .onAppear { refreshNotificationSettings() }
        // Re-read on return from iOS Settings, where these toggles actually live.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationSettings()
        }
    }

    // MARK: - Header (matches FirstLaunchView)

    private var icon: some View {
        Image(systemName: "bell.badge.circle.fill")
            .font(.system(size: 50))
            .foregroundColor(Color.blue)
            // Must match FirstLaunchView's icon frame so both titles sit at the same y.
            .frame(height: 60)
    }

    private var title: some View {
        Text("開始設定")
            .font(.system(size: 45, weight: .bold, design: .rounded))
            .padding(.top, 25)
            .foregroundStyle(.primary)
    }

    /// Card chrome shared by both blocks, so they read as one system.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }

    // MARK: - Notifications (top)

    private var notificationCard: some View {
        card {
            Toggle(isOn: Binding(
                get: { notificationStatus.isAllowed },
                set: { wants in
                    // iOS shows the system prompt once. Once it has been answered, the
                    // only way to change it is Settings, so send the user there rather
                    // than leaving a toggle that silently does nothing.
                    if wants && !notificationStatus.isDetermined {
                        requestNotifications()
                    } else if wants {
                        openAppSettings()
                    }
                }
            )) {
                Label("地震通知", systemImage: "bell.badge.fill")
                    .font(.headline)
            }
            .disabled(notificationStatus.isAllowed)

            Text("地震速報透過推播在第一時間提醒您。未允許通知將無法收到地震預警。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Same status block and recovery link as Settings, so the two screens describe
            // an identical permission state identically.
            if notificationSettings != nil {
                Divider()
                NotificationStatusRow(status: notificationStatus)
                if notificationStatus.needsAttention {
                    NotificationSettingsLink(needsAttention: true)
                }
            }
        }
    }

    // MARK: - Auto-location (bottom, the encouraged default)

    private var autoLocationCard: some View {
        card {
            Toggle(isOn: $locationManager.isAutoLocationEnabled) {
                Label("自動定位", systemImage: "location.fill")
                    .font(.headline)
            }
            .onChange(of: locationManager.isAutoLocationEnabled) { isEnabled in
                if isEnabled { locationManager.updateLocationManually() }
            }

            Text("自動依您的位置選擇最近的通知區域，移動時也會自動更新。之後可在「設定」中更改。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if locationManager.isAutoLocationEnabled {
                Divider()
                AutoLocationStatusRow(permission: permission,
                                      locationManager: locationManager)

                // Same recovery affordance as Settings: when permission is the blocker,
                // point at where it is actually fixable.
                LocationFixButton(
                    status: permission,
                    requestPermission: { locationManager.updateLocationManually() },
                    openSettings: { openAppSettings() }
                )
            }
        }
    }

    // MARK: - Manual region (only when location is denied)

    private var manualRegionCard: some View {
        card {
            Label("選擇通知區域", systemImage: "mappin.and.ellipse")
                .font(.headline)

            Label {
                Text("無法取得位置權限，請手動選擇您所在的區域。可稍後至「設定」重新開啟位置權限，改用自動定位。")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            Divider()

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

            PermissionFixButton(title: "前往設定開啟位置權限") { openAppSettings() }
        }
    }

    // MARK: - Continue

    /// Same shape, weight and position as FirstLaunchView's dismiss button, with Liquid
    /// Glass on iOS 26+ and the identical solid fill below it.
    private var continueButton: some View {
        Button(action: finish) {
            Text("開始使用")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(continueBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var continueBackground: some View {
        if #available(iOS 26.0, *) {
            Color.blue.glassEffect(.regular.tint(.blue).interactive(),
                                   in: .rect(cornerRadius: 16))
        } else {
            Color.blue
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
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound, .criticalAlert]
        ) { granted, _ in
            DispatchQueue.main.async {
                if granted { UIApplication.shared.registerForRemoteNotifications() }
                // Re-read rather than trusting `granted`: it says nothing about the
                // critical and time-sensitive sub-permissions the status row reports.
                refreshNotificationSettings()
            }
        }
    }

    private func refreshNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationSettings = settings
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
