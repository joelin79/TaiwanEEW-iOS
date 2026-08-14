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
        guard isAllowed else { return ["通知權限已關閉，將無法接收地震預警"] }
        var issues: [String] = []
        if settings.criticalAlertSetting == .disabled {
            issues.append("「重大通知」已關閉：強震通知將受靜音與專注模式限制，可能不會發出聲響")
        }
        if settings.timeSensitiveSetting == .disabled {
            issues.append("「時效性通知」已關閉：通知可能不會即時顯示")
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
        guard let settings else { return "正在檢查通知權限..." }
        switch settings.authorizationStatus {
        case .denied:        return "通知權限已關閉"
        case .notDetermined: return "尚未取得通知權限"
        default:             return issues.isEmpty ? "已取得通知權限" : "通知權限不完整"
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
