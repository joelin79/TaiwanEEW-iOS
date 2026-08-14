//
//  OnboardingPermissionsView.swift
//  TaiwanEEW
//
//  Second onboarding page, and the only decision it asks the user to make is the alert
//  region. Notification permission is requested on appear without a row of its own: it is
//  not really a choice — the app has no purpose without it — and a toggle for something
//  iOS will only ever prompt once just adds a control that stops working after the first
//  answer. Settings is where notification state is reported and repaired.
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

    @State private var notificationSettings: UNNotificationSettings? = nil

    private var notificationStatus: NotificationPermissionStatus {
        NotificationPermissionStatus(settings: notificationSettings)
    }

    /// Something is wrong with notification delivery and the user has already answered the
    /// prompt: either they refused outright, or they allowed notifications while critical
    /// or time-sensitive alerts are off, which quietly downgrades warnings to something an
    /// earthquake could sleep through. The isDetermined guard keeps the page from warning
    /// about a refusal that has not happened yet, since an unanswered prompt is not
    /// "allowed" either.
    private var notificationsNeedFixing: Bool {
        notificationStatus.isDetermined && notificationStatus.needsAttention
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

                Group {
                    if needsManualRegion {
                        manualRegionCard
                    } else {
                        autoLocationCard
                    }
                }
                .padding(.top, 24)

                if notificationsNeedFixing {
                    notificationWarning
                        .padding(.top, 16)
                }

                // Absorbs the slack so the button lands at the same height as the terms
                // screen's, and collapses first if a small display needs the room.
                Spacer(minLength: 20)

                continueButton
            }
            .frame(maxWidth: maxWidth, maxHeight: .infinity)
            .frame(maxWidth: .infinity)     // center the content
            .padding(.horizontal, 20)
            .padding(.vertical, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.background))
        // How this page enters and leaves is choreographed with the terms screen at the
        // call site in TaiwanEEWApp, so the two stay in step.
        .animation(.default, value: needsManualRegion)
        .animation(.default, value: notificationsNeedFixing)
        .onAppear { requestNotifications() }
        // Re-read on return from iOS Settings, which is where the warning sends them.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationSettings()
        }
    }

    /// Reports whatever is currently degrading delivery, using the same status row as
    /// Settings. Tinted by severity rather than always red — a refused permission and a
    /// disabled critical alert are not the same problem — and shaped like the region card
    /// so it reads as part of the page rather than an error pasted onto it.
    ///
    /// No toggle accompanies it: iOS will not prompt twice, so Settings is the only route
    /// that actually changes anything.
    private var notificationWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotificationStatusRow(status: notificationStatus)

            Divider()

            NotificationSettingsLink(needsAttention: true)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(notificationStatus.color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(notificationStatus.color.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Header (matches FirstLaunchView)

    private var icon: some View {
        // Location, not a bell: the region is the only thing this page puts on screen.
        Image(systemName: "location.circle.fill")
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

    // MARK: - Auto-location (the only thing on this page)

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
        //
        // Auto-location has to be resolved here rather than read from storage: the
        // onLocationChanged callback that normally writes these indices is registered on
        // the TabView, which does not exist yet during onboarding. Without this the card
        // would show the user's real district while the stored indices were still 0/0 —
        // the first district in the list — and that is what would get subscribed.
        var cityIndex = subscribedCityIndex
        var districtIndex = subscribedDistrictIndex
        if locationManager.isAutoLocationEnabled,
           let location = locationManager.currentLocation {
            // Same call the card displays from, so what is committed is what was shown.
            (cityIndex, districtIndex, _) = locationManager.findClosestDistrict(to: location.coordinate)
            subscribedCityIndex = cityIndex
            subscribedDistrictIndex = districtIndex
        }

        NotificationManager.setNotifyMode(
            cityIndex: cityIndex,
            districtIndex: districtIndex,
            threshold: NotifyThreshold(rawValue: UserDefaults.standard.string(forKey: "notifyThreshold") ?? "eg3") ?? .eg3
        )
        onDone()
    }

    /// Fires the system notification prompt with no UI of its own — the page asks for the
    /// permission without spending a row on it.
    ///
    /// Safe to call on every appearance: iOS presents the prompt only while the choice is
    /// still .notDetermined and otherwise just replays the existing answer. Notification
    /// state is not surfaced here; Settings is where it is reported and repaired.
    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound, .criticalAlert]
        ) { granted, _ in
            DispatchQueue.main.async {
                if granted { UIApplication.shared.registerForRemoteNotifications() }
                // Read the result back so a refusal surfaces the warning immediately,
                // rather than waiting for the next time the app becomes active.
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
