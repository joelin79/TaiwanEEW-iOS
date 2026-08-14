//
//  PermissionViews.swift
//  TaiwanEEW
//
//  The permission status block and its recovery affordances, shared by Settings and
//  onboarding. Both screens ask for the same two permissions, so they render them with
//  the same views rather than two lookalike implementations that drift apart.
//

import SwiftUI

/// Icon + headline + detail lines describing one permission's current state.
///
/// HStack alignment is deliberately left at centre to match how Settings has always
/// rendered these rows.
struct PermissionStatusRow<Detail: View>: View {
    let icon: String
    let color: Color
    let headline: String
    @ViewBuilder let detail: Detail

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(.headline)
                detail
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

/// A caption line beneath a permission headline. Wraps instead of truncating, because
/// every one of these explains something the user has to act on.
struct PermissionDetailText: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Sends the user where a permission is actually fixable. Identical weight and colour on
/// both screens so the affordance never reads as two different things.
struct PermissionFixButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .foregroundColor(.blue)
    }
}

/// Deep link to the app's own page in iOS Settings, where the critical and time-sensitive
/// toggles live. Reads as a fix-this action while something is wrong, and as a plain
/// shortcut once everything is in order.
struct NotificationSettingsLink: View {
    let needsAttention: Bool

    var body: some View {
        Link(destination: UIApplication.appNotificationSettingsURL!) {
            HStack {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundStyle(.red)
                Text(needsAttention ? "修正強制警報設定" : "強制警報設定")
                    .foregroundStyle(.blue)
            }
        }
    }
}

/// Everything currently degrading notification delivery, or a single line confirming all
/// is well. Issues take the status colour rather than a fixed orange, so a refused
/// permission reads red and a merely disabled sub-permission reads orange — they are not
/// the same severity, and the icon already made that distinction.
struct NotificationStatusRow: View {
    let status: NotificationPermissionStatus

    var body: some View {
        PermissionStatusRow(icon: status.icon,
                            color: status.color,
                            headline: status.headline) {
            ForEach(status.issues, id: \.self) { issue in
                PermissionDetailText(text: issue, color: status.color)
            }
        }
    }
}

/// Auto-location status: the permission headline, which district is currently matched and
/// how far away it is, and what the permission state actually means for background updates.
struct AutoLocationStatusRow: View {
    let permission: LocationPermissionStatus
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        PermissionStatusRow(icon: permission.icon,
                            color: permission.color,
                            headline: permission.headline) {
            if let location = locationManager.currentLocation {
                let (cityIndex, districtIndex, distance) = locationManager.findClosestDistrict(to: location.coordinate)
                let districtName = Location.cities[cityIndex].district[districtIndex].districtName
                let distanceKm = String(format: "%.1f", distance / 1000)
                HStack {
                    Text("最近震度參考點：\(districtName)")
                        .font(.caption)
                    Text("(\(distanceKm) 公里)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if permission.canFetchLocation {
                // Only claim we are working on it when permission actually allows it;
                // otherwise the detail line below explains what is blocking.
                PermissionDetailText(text: "正在取得位置...")
            }

            // "Background updates enabled" is reassurance, so it stays secondary; every
            // other state is a problem and takes the status colour.
            PermissionDetailText(
                text: permission.detail,
                color: permission.status == .authorizedAlways ? .secondary : permission.color
            )
        }
    }
}

/// The location recovery button for a given authorization state, or nothing when
/// permission is already granted and there is no action left to offer.
struct LocationFixButton: View {
    let status: LocationPermissionStatus
    /// Requests permission in the .notDetermined case, where a deep link would be a
    /// detour — iOS can still show the prompt.
    let requestPermission: () -> Void
    let openSettings: () -> Void

    var body: some View {
        switch status.status {
        case .denied, .restricted:
            PermissionFixButton(title: "前往設定開啟位置權限", action: openSettings)
        case .authorizedWhenInUse:
            PermissionFixButton(title: "前往設定選擇「一律允許」", action: openSettings)
        case .notDetermined:
            // updateLocationManually() requests permission in this state rather than
            // refreshing, so label it for what it actually does.
            PermissionFixButton(title: "允許位置權限", action: requestPermission)
        default:
            // Manual refresh hidden: with permission granted, location already updates on
            // its own, so the button only invited confusion.
            EmptyView()
        }
    }
}
