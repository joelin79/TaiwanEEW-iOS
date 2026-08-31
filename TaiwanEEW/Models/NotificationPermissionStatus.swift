//
//  NotificationPermissionStatus.swift
//  TaiwanEEW
//
//  Shared presentation of UNNotificationSettings so Settings and onboarding describe
//  notification permission with the same wording, icon and colour — the counterpart to
//  LocationPermissionStatus.
//
//  "Allowed" alone is not enough to promise an alert will arrive: critical and
//  time-sensitive alerts are separate iOS toggles that silently downgrade delivery when
//  off, which the user would otherwise only discover during an earthquake.
//

import SwiftUI
import UserNotifications

struct NotificationPermissionStatus {
    /// nil until the async read completes, which is why every accessor below has to
    /// tolerate the unknown state rather than assuming denied.
    let settings: UNNotificationSettings?

    var isAllowed: Bool {
        guard let settings else { return false }
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

    /// iOS has recorded an answer, so the one-time prompt is spent and only Settings can
    /// change it now. Onboarding uses this to decide whether its toggle can still prompt.
    var isDetermined: Bool {
        guard let settings else { return false }
        return settings.authorizationStatus != .notDetermined
    }

    /// Everything currently degrading delivery, worst first.
    var issues: [String] {
        guard let settings else { return [] }
        guard isAllowed else {
            return [NSLocalizedString("notif-denied-issue-string", comment: "Notifications refused outright")]
        }
        var issues: [String] = []
        if settings.criticalAlertSetting == .disabled {
            issues.append(NSLocalizedString("notif-critical-off-string", comment: "Critical alerts off: warnings obey Silent and Focus"))
        }
        if settings.timeSensitiveSetting == .disabled {
            issues.append(NSLocalizedString("notif-timesensitive-off-string", comment: "Time-sensitive off: warnings may be delayed"))
        }
        return issues
    }

    /// The settings link is a fix rather than a shortcut. False until the read completes,
    /// so the UI never accuses the user of a problem it has not confirmed yet.
    var needsAttention: Bool { !issues.isEmpty }

    /// Describes the iOS permission, not whether alerts are actually being delivered — the
    /// user may separately have set the intensity threshold to off, and calling that
    /// "啟用" would read as a contradiction.
    var headline: String {
        guard let settings else {
            return NSLocalizedString("notif-checking-string", comment: "The async read has not returned yet")
        }
        switch settings.authorizationStatus {
        case .denied:        return NSLocalizedString("notif-denied-string", comment: "")
        case .notDetermined: return NSLocalizedString("notif-notdetermined-string", comment: "")
        default:             return issues.isEmpty
            ? NSLocalizedString("notif-allowed-string", comment: "Allowed with every sub-permission on")
            : NSLocalizedString("notif-incomplete-string", comment: "Allowed but a sub-permission is off")
        }
    }

    var icon: String {
        guard let settings else { return "questionmark.circle.fill" }
        switch settings.authorizationStatus {
        case .denied:        return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        default:             return issues.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        guard let settings else { return .orange }
        switch settings.authorizationStatus {
        case .denied:        return .red
        case .notDetermined: return .orange
        default:             return issues.isEmpty ? .green : .orange
        }
    }
}
