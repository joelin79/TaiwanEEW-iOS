//
//  DrillAlertPreference.swift
//  TaiwanEEW
//
//  Shared by the app and the notification service extension.
//

import Foundation

/// Whether non-`Actual` reports — CWA's `Exercise`, `System` and `Test` — should be delivered
/// silently instead of as critical alerts.
///
/// The annual national drill is published to the same SNS topics as a real earthquake, with an
/// identical payload apart from the Chinese `[演練]` marker in the title. At intensity ≥3 the
/// backend sends it `critical`, so it bypasses the mute switch, Focus and Do Not Disturb — which
/// is how a routine drill wakes someone sleeping off a night shift.
///
/// iOS cannot withhold a push that has arrived; a `UNNotificationServiceExtension` may modify
/// content, not drop it. So the drill still lands in Notification Center — it just arrives with
/// no sound and no screen wake.
///
/// This lives in the app target but is compiled into the extension too (see the extension's
/// membership exception in `project.pbxproj`), because the two processes have separate
/// containers and must agree on the suite name, the key and the predicate.
enum DrillAlertPreference {

    /// Must match `com.apple.security.application-groups` in **both** targets' entitlements.
    /// Without the App Group the extension gets its own `UserDefaults` and can never see what
    /// the user chose in Settings.
    static let suiteName = "group.com.joedev.TaiwanEEW"

    static let storageKey = "drillAlertsMuted"

    /// Defaults to `false` — drills alert normally. Every failure here (App Group not
    /// provisioned, suite unreadable, key never written) therefore degrades to the existing
    /// behaviour rather than silencing anything. Nothing in this file can make the app
    /// *quieter* than the user asked for.
    static var isMuted: Bool {
        UserDefaults(suiteName: suiteName)?.bool(forKey: storageKey) ?? false
    }

    /// Whether a notification carrying `status` should be delivered silently.
    ///
    /// Expressed as "not `Actual`" rather than an allowlist of the three known non-actual
    /// statuses, so a status CWA adds later is treated as not-a-real-earthquake by default.
    /// Both guards below are load-bearing, in opposite directions:
    ///
    /// - **Absent** is every payload from a backend that predates the `status` field. It must
    ///   fall through to alerting, or shipping this would have silenced real warnings until the
    ///   server caught up.
    /// - **Present but blank** is the sharper edge. `Earthquake.status` on the server is read
    ///   straight out of the CWA XML, so a malformed document can yield `""` — and `"" != "actual"`
    ///   is `true`. Without the emptiness check a real alert would be silenced. The server also
    ///   omits the key rather than sending it empty; this is the second line of that defence.
    static func shouldSilence(status: String?, isMuted: Bool) -> Bool {
        guard isMuted else { return false }
        guard let status,
              !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return status.lowercased() != "actual"
    }
}
