//
//  NotificationService.swift
//  TaiwanEEWServiceExtension
//
//  Created by joejoe79 on 2025/12/27.
//

import UserNotifications
import os.log

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NotificationService")

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            // Log the incoming payload for debugging
            logger.info("Received notification payload: \(request.content.userInfo)")

            // Process the notification
            processNotification(content: bestAttemptContent)

            // Deliver the modified content
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            logger.warning("Service extension time expiring, delivering best attempt content")
            contentHandler(bestAttemptContent)
        }
    }

    private func processNotification(content: UNMutableNotificationContent) {
        // Extract "ins" field from the payload
        guard let insValue = content.userInfo["ins"] as? String else {
            logger.info("No 'ins' field found, using original sound")
            return
        }

        logger.info("Found 'ins' value: \(insValue)")

        // Map intensity to sound filename
        guard let soundFilename = mapIntensityToSound(intensity: insValue) else {
            logger.warning("Invalid 'ins' value: \(insValue), using original sound")
            return
        }

        let soundName = UNNotificationSoundName(rawValue: soundFilename)

        // UNNotificationSound(named:) always plays as a regular sound - for alerts the
        // backend marked critical (interruption-level, set from the aps payload before this
        // extension runs), that silently drops the mute-switch/Do Not Disturb bypass the
        // critical-alerts entitlement exists for. criticalSoundNamed preserves it.
        if content.interruptionLevel == .critical {
            let volume = Float(originalSoundVolume(from: content) ?? 1.0)
            content.sound = UNNotificationSound.criticalSoundNamed(soundName, withAudioVolume: volume)
            logger.info("Replaced notification sound with critical sound: \(soundFilename) at volume \(volume)")
        } else {
            content.sound = UNNotificationSound(named: soundName)
            logger.info("Replaced notification sound with: \(soundFilename)")
        }
    }

    private func originalSoundVolume(from content: UNMutableNotificationContent) -> Double? {
        guard let aps = content.userInfo["aps"] as? [String: Any],
              let sound = aps["sound"] as? [String: Any] else {
            return nil
        }
        return sound["volume"] as? Double
    }

    private func mapIntensityToSound(intensity: String) -> String? {
        // Mapping based on CWA intensity scale
        switch intensity {
        case "1":
            return "1_zh.wav"
        case "2":
            return "2_zh.wav"
        case "3":
            return "3_zh.wav"
        case "4":
            return "4_bi.wav"
        case "5-":
            return "5L_bi.wav"
        case "5+":
            return "5H_bi.wav"
        case "6-":
            return "6L_bi.wav"
        case "6+":
            return "6H_bi.wav"
        case "7":
            return "7_bi.wav"
        default:
            return nil // Invalid intensity, will use original sound
        }
    }

}
