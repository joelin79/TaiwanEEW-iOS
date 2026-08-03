//
//  LocationPermissionStatus.swift
//  TaiwanEEW
//
//  Shared presentation of CLAuthorizationStatus so Settings and onboarding describe
//  location permission with the same wording, icon and colour. Each state fails
//  differently: "While Using" cannot update in the background, and denied/notDetermined
//  cannot read location at all — none of which is "enabled".
//

import SwiftUI
import CoreLocation

struct LocationPermissionStatus {
    let status: CLAuthorizationStatus

    /// Permission allows reading location at all (foreground counts).
    var canFetchLocation: Bool {
        status == .authorizedAlways || status == .authorizedWhenInUse
    }

    /// Permission is denied or restricted — the user must go to Settings to recover.
    var isBlocked: Bool {
        status == .denied || status == .restricted
    }

    var headline: String {
        switch status {
        case .authorizedAlways:    return "自動定位運作中"
        case .authorizedWhenInUse: return "自動定位僅前景可用"
        case .denied, .restricted: return "自動定位無法運作"
        case .notDetermined:       return "尚未取得位置權限"
        @unknown default:          return "自動定位狀態不明"
        }
    }

    var detail: String {
        switch status {
        case .authorizedAlways:    return "背景更新已啟用"
        case .authorizedWhenInUse: return "僅在開啟App時更新，需要「一律允許」才能在背景自動切換區域"
        case .denied:              return "位置權限已關閉，無法取得您的位置"
        case .restricted:          return "位置權限受到限制，無法取得您的位置"
        case .notDetermined:       return "尚未授予位置權限，無法取得您的位置"
        @unknown default:          return "無法判斷位置權限狀態"
        }
    }

    var icon: String {
        switch status {
        case .authorizedAlways:    return "checkmark.circle.fill"
        case .authorizedWhenInUse: return "exclamationmark.triangle.fill"
        case .denied, .restricted: return "xmark.circle.fill"
        case .notDetermined:       return "questionmark.circle.fill"
        @unknown default:          return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch status {
        case .authorizedAlways:    return .green
        case .authorizedWhenInUse: return .orange
        case .denied, .restricted: return .red
        case .notDetermined:       return .orange
        @unknown default:          return .orange
        }
    }
}
