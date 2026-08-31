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
        case .authorizedAlways:    return NSLocalizedString("loc-always-string", comment: "Auto-location is fully working")
        case .authorizedWhenInUse: return NSLocalizedString("loc-wheninuse-string", comment: "Auto-location works only in the foreground")
        case .denied, .restricted: return NSLocalizedString("loc-denied-string", comment: "Auto-location cannot work at all")
        case .notDetermined:       return NSLocalizedString("loc-notdetermined-string", comment: "Location permission has not been asked for yet")
        @unknown default:          return NSLocalizedString("loc-unknown-string", comment: "Unrecognised future authorization state")
        }
    }

    var detail: String {
        switch status {
        case .authorizedAlways:    return NSLocalizedString("loc-always-detail-string", comment: "")
        case .authorizedWhenInUse: return NSLocalizedString("loc-wheninuse-detail-string", comment: "")
        case .denied:              return NSLocalizedString("loc-denied-detail-string", comment: "")
        case .restricted:          return NSLocalizedString("loc-restricted-detail-string", comment: "Restricted by parental controls or MDM, not by the user")
        case .notDetermined:       return NSLocalizedString("loc-notdetermined-detail-string", comment: "")
        @unknown default:          return NSLocalizedString("loc-unknown-detail-string", comment: "")
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
