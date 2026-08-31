//
//  NotificationManager.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/6/12.
//

import Foundation
import AWSSNS
import UserNotifications
import FirebaseMessaging
import os.log

struct NotificationManager {
    private static var defaults = UserDefaults.standard
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NotificationManager")
    
    static func setNotifyMode(cityIndex: Int, districtIndex: Int, threshold: NotifyThreshold){
        AWSManager.setNotifyMode(cityIndex: cityIndex, districtIndex: districtIndex, threshold: threshold)
        FCMManager.setNotifyMode(cityIndex: cityIndex, districtIndex: districtIndex, threshold: threshold)
    }
    
    /// Marks a local notification as one that should open this app's iOS Settings page
    /// when tapped. Read back by AppDelegate's notification response handler.
    static let deepLinkKey = "deepLink"
    static let deepLinkAppSettings = "appSettings"

    /// - Parameter opensAppSettings: tapping the notification deep links to the app's
    ///   Settings page, so a user told to fix a permission does not have to go find it.
    func push(_ title:String, _ body:String, opensAppSettings: Bool = false) {

        Self.logger.info("Sending local notification: \(title)")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if opensAppSettings {
            content.userInfo = [Self.deepLinkKey: Self.deepLinkAppSettings]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    class AWSManager {
        static let sns = AWSSNS.default()
        private static let operationQueue = DispatchQueue(label: "aws.subscription.queue", qos: .userInitiated)
        
        // MARK: - Version Topic Management
        /// Formats a marketing version as its SNS topic name, e.g. "2.1.0" -> "ver2_1_0".
        /// Split out from the bundle lookup so the formatting can be tested directly
        /// instead of only against whatever version the test host happens to carry.
        static func versionTopic(for version: String) -> String {
            let versionComponents = version.components(separatedBy: ".")

            // Ensure we have at least 3 components (major.minor.patch)
            let major = versionComponents.count > 0 ? versionComponents[0] : "2"
            let minor = versionComponents.count > 1 ? versionComponents[1] : "1"
            let patch = versionComponents.count > 2 ? versionComponents[2] : "0"

            return "ver\(major)_\(minor)_\(patch)"
        }

        private static func getVersionTopic() -> String {
            versionTopic(for: getCurrentVersion())
        }
        
        static func getCurrentVersion() -> String {
            return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.0"
        }
        
        static func subscribeToVersionTopic() async -> Bool {
            let versionTopic = getVersionTopic()
            logger.info("Subscribing to version topic: \(versionTopic)")
            return await subscribe(to: versionTopic)
        }
        
        static func cleanupOldVersionTopics() async {
            let currentVersionTopic = getVersionTopic()
            let currentTopics = currentSubscribedTopics.keys
            
            // Find and unsubscribe from old version topics
            let oldVersionTopics = currentTopics.filter { topic in
                topic.hasPrefix("ver") && topic != currentVersionTopic
            }
            
            if !oldVersionTopics.isEmpty {
                logger.info("Cleaning up old version topics: \(oldVersionTopics)")
                for topic in oldVersionTopics {
                    await unsubscribe(from: topic)
                }
            }
        }
        
        /// Topics owned by the notification threshold: the district alert topics
        /// (e.g. 10501eg3) and the "off" reminder topic. Version topics are owned by
        /// subscribeToVersionTopic()/cleanupOldVersionTopics() and must never be
        /// unsubscribed as a side effect of changing threshold or district - doing so
        /// silently drops the user off version announcements until the next cold launch.
        static func isThresholdManagedTopic(_ topic: String) -> Bool {
            topic.range(of: #"^\d{5}eg\d$"#, options: .regularExpression) != nil
                || topic == NotifyThreshold.off.getTopicKey()
        }

        static func generateTopicKeys(for cityIndex: Int, districtIndex: Int, threshold: NotifyThreshold) -> [String] {
            var topicsToSubscribe: [String] = []

            switch threshold {
                case .off:
                    topicsToSubscribe.append(threshold.getTopicKey())
                default:
                    let startIndex = threshold.getIntValue()
                    let endIndex = 4
                    let districtToSubscribe = Location.cities[cityIndex].district[districtIndex].getTopicCode()
                    for i in startIndex...endIndex {
                        let topic = districtToSubscribe + "eg\(i)"
                        topicsToSubscribe.append(topic)
                    }
            }
            logger.debug("Topics to subscribe: \(topicsToSubscribe)")
            return topicsToSubscribe
        }
        
        static func setNotifyMode(cityIndex: Int, districtIndex: Int, threshold: NotifyThreshold) {
            let newTopicKeys = generateTopicKeys(for: cityIndex, districtIndex: districtIndex, threshold: threshold)
            
            operationQueue.async {
                Task {
                    // First unsubscribe from old topics, leaving version topics alone
                    let topicsToUnsubscribe = currentSubscribedTopics.keys.filter {
                        !newTopicKeys.contains($0) && isThresholdManagedTopic($0)
                    }
                    for topic in topicsToUnsubscribe {
                        await unsubscribe(from: topic)
                    }
                    
                    // Then subscribe to new topics
                    for topic in newTopicKeys {
                        await subscribe(to: topic)
                    }
                }
            }
        }
        
        static func subscribe(to topic: String) async -> Bool {
            // Validate endpoint ARN before attempting subscription
            guard let endpointArn = UserDefaults.standard.string(forKey: "endpointArnForSNS"),
                  !endpointArn.isEmpty else {
                logger.error("No valid endpoint ARN found for topic: \(topic)")
                return false
            }
            
            // Check if already subscribed
            if isSubscribed(to: topic) {
                logger.debug("Already subscribed to topic: \(topic)")
                return true
            }
            
            let topicArn = AppConfig.topicArn(topic)
            
            return await withCheckedContinuation { continuation in
                let subscribeInput = AWSSNSSubscribeInput()
                subscribeInput?.topicArn = topicArn
                subscribeInput?.protocols = "application"
                subscribeInput?.endpoint = endpointArn
                
                sns.subscribe(subscribeInput!) { (output, error) in
                    if let error = error {
                        logger.error("Error subscribing to \(topic): \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    } else if let subscriptionArn = output?.subscriptionArn {
                        // Only update local state after successful AWS operation
                        self.subscriptionsARN[topicArn] = subscriptionArn
                        self.currentSubscribedTopics[topic] = true
                        self.saveSubscriptionStatus()
                        logger.info("Successfully subscribed to \(topic) with ARN: \(subscriptionArn)")
                        continuation.resume(returning: true)
                    } else {
                        logger.warning("Unexpected response when subscribing to \(topic)")
                        continuation.resume(returning: false)
                    }
                }
            }
        }

        static func unsubscribe(from topic: String) async -> Bool {
            // Check if actually subscribed
            if !isSubscribed(to: topic) {
                logger.debug("Not subscribed to topic: \(topic)")
                return true
            }
            
            let topicArn = AppConfig.topicArn(topic)
            
            // Get subscription ARN
            guard let subscriptionArn = subscriptionsARN[topicArn] else {
                logger.warning("No active subscription ARN found for topic: \(topic)")
                // Clean up local state since we don't have a valid subscription
                currentSubscribedTopics[topic] = nil
                saveSubscriptionStatus()
                return false
            }
            
            return await withCheckedContinuation { continuation in
                let unsubscribeInput = AWSSNSUnsubscribeInput()
                unsubscribeInput?.subscriptionArn = subscriptionArn
                
                sns.unsubscribe(unsubscribeInput!) { (error) in
                    if let error = error {
                        logger.error("Error unsubscribing from topic \(topic): \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    } else {
                        // Only update local state after successful AWS operation
                        self.subscriptionsARN.removeValue(forKey: topicArn)
                        self.currentSubscribedTopics[topic] = nil
                        self.saveSubscriptionStatus()
                        logger.info("Successfully unsubscribed from topic: \(topic)")
                        continuation.resume(returning: true)
                    }
                }
            }
        }

        static func isSubscribed(to topic: String) -> Bool {
            return currentSubscribedTopics[topic] != nil
        }
        
        // MARK: - State Validation
        static func validateSubscriptionState() {
            logger.info("Validating AWS subscription state...")
            let localTopics = currentSubscribedTopics.keys
            let localSubscriptions = subscriptionsARN.keys
            
            logger.info("Local subscribed topics: \(localTopics)")
            logger.debug("Local subscription ARNs: \(localSubscriptions)")
            
            // Check for orphaned subscription ARNs
            let orphanedARNs = localSubscriptions.filter { topicArn in
                let topic = topicArn.replacingOccurrences(of: AppConfig.snsArnPrefix, with: "")
                return !localTopics.contains(topic)
            }
            
            if !orphanedARNs.isEmpty {
                logger.warning("Found orphaned subscription ARNs: \(orphanedARNs)")
                // Clean up orphaned ARNs
                for arn in orphanedARNs {
                    subscriptionsARN.removeValue(forKey: arn)
                }
                saveSubscriptionStatus()
            }
        }
        
        // MARK: - Subscription Recovery
        static func recoverSubscriptionState() async {
            logger.info("Recovering AWS subscription state...")

            // If the live endpoint ARN differs from the one our local subscriptions were last
            // confirmed against (APNs token rotated after a restore/reinstall/device migration
            // while the app wasn't running), every subscription below is attached to a now-dead
            // endpoint. SNS never reports this back to us, so the missing/extra diff below would
            // otherwise see nothing wrong and leave the device silently unsubscribed from all
            // EEW topics. Discard the stale bookkeeping so every expected topic is treated as
            // missing and gets resubscribed under the current endpoint; SNS Subscribe is
            // idempotent per (topic, endpoint), so this is safe to do even when nothing changed.
            let liveEndpointArn = UserDefaults.standard.string(forKey: "endpointArnForSNS")
            if let liveEndpointArn, liveEndpointArn != subscribedEndpointArn {
                logger.warning("Endpoint ARN changed (was: \(subscribedEndpointArn ?? "none"), now: \(liveEndpointArn)) - discarding stale subscription state")
                currentSubscribedTopics = [:]
                subscriptionsARN = [:]
                subscribedEndpointArn = liveEndpointArn
            }

            // Until the user has picked a region in onboarding, do not subscribe to any
            // district. UserDefaults returns 0/0 for unset indices, which is a real
            // district (the first in the list) — subscribing to it would silently send a
            // brand-new user another region's earthquake alerts. The version topic is
            // still handled below so announcements work from first launch.
            guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else {
                logger.info("Onboarding incomplete - skipping district subscription")
                await cleanupOldVersionTopics()
                await subscribeToVersionTopic()
                return
            }

            // Get current app settings
            let cityIndex = UserDefaults.standard.integer(forKey: "subscribedCityIndex")
            let districtIndex = UserDefaults.standard.integer(forKey: "subscribedDistrictIndex")
            let threshold = NotifyThreshold(rawValue: UserDefaults.standard.string(forKey: "notifyThreshold") ?? "eg3") ?? .eg3
            
            // Validate current subscriptions match settings
            let expectedTopics = generateTopicKeys(for: cityIndex, districtIndex: districtIndex, threshold: threshold)
            let currentTopics = currentSubscribedTopics.keys
            
            // Find missing subscriptions
            let missingTopics = expectedTopics.filter { !currentTopics.contains($0) }
            
            if !missingTopics.isEmpty {
                logger.info("Found missing subscriptions: \(missingTopics)")
                // Resubscribe to missing topics
                for topic in missingTopics {
                    await subscribe(to: topic)
                }
            }
            
            // Find extra subscriptions (should be cleaned up by setNotifyMode, but just in
            // case). Version topics are excluded: they are never in expectedTopics, so
            // including them here would unsubscribe the current version topic on every
            // launch only for cleanupOldVersionTopics/subscribeToVersionTopic below to add
            // it straight back.
            let extraTopics = currentTopics.filter {
                !expectedTopics.contains($0) && isThresholdManagedTopic($0)
            }
            if !extraTopics.isEmpty {
                logger.info("Found extra subscriptions: \(extraTopics)")
                // Unsubscribe from extra topics
                for topic in extraTopics {
                    await unsubscribe(from: topic)
                }
            }
            
            // Clean up old version topics and ensure current version topic subscription
            await cleanupOldVersionTopics()
            await subscribeToVersionTopic()
        }
        
        static var subscribedEndpointArn: String? { // the endpoint ARN local subscriptions were last confirmed against
            get {
                return defaults.string(forKey: "subscribedEndpointArn")
            }
            set {
                defaults.set(newValue, forKey: "subscribedEndpointArn")
            }
        }

        static var subscriptionsARN: [String: String] { // [TopicARN: SubscriptionARN]
            get {
                return defaults.dictionary(forKey: "subscriptionsARN") as? [String: String] ?? [:]
            }
            set {
                defaults.set(newValue, forKey: "subscriptionsARN")
            }
        }
        
        static var currentSubscribedTopics: [String: Bool] {
            get {
                return defaults.dictionary(forKey: "AWSsubscribedTopics") as? [String: Bool] ?? [:]
            }
            set {
                defaults.set(newValue, forKey: "AWSsubscribedTopics")
            }
        }

        private static func saveSubscriptionStatus() {
            currentSubscribedTopics = currentSubscribedTopics
            subscriptionsARN = subscriptionsARN
        }
        
    }
    
    @available(*, deprecated, message: "珍惜生命，遠離 FCM。")
    class FCMManager {
        
        private static func generateTopicKeys(for cityIndex: Int, districtIndex: Int, threshold: NotifyThreshold) -> [String] {
            var districtToSubscribe: String = ""
            var thresholdToSubscribe: String = ""
            
            switch threshold {
                case .off:
                    thresholdToSubscribe = threshold.getTopicKey()
                default:
                    districtToSubscribe = Location.cities[cityIndex].district[districtIndex].getTopicCode()
                    thresholdToSubscribe = threshold.getTopicKey()
                }

            return [districtToSubscribe, thresholdToSubscribe]
        }
        
        static func setNotifyMode(cityIndex: Int, districtIndex: Int, threshold: NotifyThreshold) {
            // Set user property for Analytics
            // TODO: fix Analytics not returning
            AnalysicsManager.shared.setUserProperty(value: Location.cities[cityIndex].id, property: "subscribedCity")
            AnalysicsManager.shared.setUserProperty(value: Location.cities[cityIndex].district[districtIndex].id, property: "subscribedDistrict")
            AnalysicsManager.shared.setUserProperty(value: threshold.getTopicKey(), property: "notifyThreshold")
            
            let newTopicKeys = generateTopicKeys(for: cityIndex, districtIndex: districtIndex, threshold: threshold)

            // Unsubscribe from unnecessary topics
            currentSubscribedTopics.keys.forEach { topic in
                if !newTopicKeys.contains(topic) {
                    unsubscribe(from: topic)
                }
            }

            // Subscribe to new topics
            newTopicKeys.forEach { topic in
                subscribe(to: topic)
            }
        }
        
        static func subscribe(to topic: String) {
            if !isSubscribed(to: topic) {
                // Perform the subscribe operation here.
                Messaging.messaging().subscribe(toTopic: topic) { error in }
                currentSubscribedTopics[topic] = true
                saveSubscriptionStatus()
            }
        }

        static func unsubscribe(from topic: String) {
            if isSubscribed(to: topic) {
                // Perform the unsubscribe operation here.
                Messaging.messaging().unsubscribe(fromTopic: topic) { error in }
                currentSubscribedTopics[topic] = nil
                saveSubscriptionStatus()
            }
        }

        static func isSubscribed(to topic: String) -> Bool {
            return currentSubscribedTopics[topic] != nil
        }

        static var currentSubscribedTopics: [String: Bool] {
            get {
                return defaults.dictionary(forKey: "FCMsubscribedTopics") as? [String: Bool] ?? [:]
            }
            set {
                defaults.set(newValue, forKey: "FCMsubscribedTopics")
            }
        }

        private static func saveSubscriptionStatus() {
            currentSubscribedTopics = currentSubscribedTopics // Force saving to UserDefaults
        }

    }
}




