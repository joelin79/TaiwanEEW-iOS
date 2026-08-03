//
//  TaiwanEEWApp.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/7/5.
//
//  This file contains the main entry point of the TaiwanEEW app.
//

import SwiftUI
import AWSSNS
import Firebase
import FirebaseAppCheck
import RevenueCat
import UserNotifications
import BackgroundTasks
import os.log


@main
struct TaiwanEEWApp: App {
    static let DEBUG = false
    static let PRODUCTION = !DEBUG
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TaiwanEEWApp")
    @Environment(\.scenePhase) private var phase
    let appRefreshInterval: TimeInterval = 10           // seconds
    
    // selection variables accessable between views
    @AppStorage("historyRange") var historyRange: TimeRange = .year
    @AppStorage("subscribedCityIndex") var subscribedCityIndex: Int = 0
    @AppStorage("subscribedDistrictIndex") var subscribedDistrictIndex: Int = 0
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true
    // Gates district subscription until the user has actually chosen a region. Existing
    // installs are migrated to true on launch (see AppDelegate) so upgrades never see
    // onboarding and never lose their subscription.
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("notifyThreshold") var notifyThreshold: NotifyThreshold = .eg3
    
    init() {
        Purchases.configure(withAPIKey: AppConfig.revenueCatKey)
    }

    var body: some Scene {
        WindowGroup {
            let _ = logger.info("[Init] isFirstLaunch is currently \(isFirstLaunch)")
            if isFirstLaunch {
                FirstLaunchView(onDismiss: {
                    withAnimation {
                        isFirstLaunch = false
                    }
                })
            } else if !hasCompletedOnboarding {
                NavigationView {
                    OnboardingPermissionsView(onDone: {
                        withAnimation { hasCompletedOnboarding = true }
                    })
                }
                .navigationViewStyle(.stack)
            } else {
                TabView {
                    AlertView(eventManager: EventDispatcher(subscribedCityIndex: $subscribedCityIndex, subscribedDistrictIndex: $subscribedDistrictIndex), subscribedCityIndex: $subscribedCityIndex, subscribedDistrictIndex: $subscribedDistrictIndex, notifyThreshold: $notifyThreshold)
                        .tabItem {
                            Label(LocalizedStringKey("nav-alert-string"), systemImage: "exclamationmark.triangle")    // TODO: localization
                        }
                    
                    if TaiwanEEWApp.DEBUG {
                        HistoryView(viewModel: EarthquakeViewModel())
                            .tabItem {
                                Label(LocalizedStringKey("nav-history-string"), systemImage: "chart.bar.doc.horizontal")
                            }
                    }
                    
                    // Second entry point to donations; the Settings screen still presents
                    // this same view modally, which is why it takes the dismiss controls
                    // away here rather than showing a close button with nothing to close.
                    DonateView(showsDismissControls: false)
                        .tabItem {
                            Label(LocalizedStringKey("nav-donate-string"), systemImage: "heart")
                        }

                    SettingsView(
                        onHistoryRangeChanged: { newValue in
                            historyRange = newValue
                        }, onSubscribedLocChanged: { newValue in
                            subscribedCityIndex = newValue[0]
                            subscribedDistrictIndex = newValue[1]
                            NotificationManager.setNotifyMode(cityIndex: subscribedCityIndex, districtIndex: subscribedDistrictIndex, threshold: notifyThreshold)
                        }, onNotifyThresholdChanged: { newValue in
                            notifyThreshold = newValue
                            NotificationManager.setNotifyMode(cityIndex: subscribedCityIndex, districtIndex: subscribedDistrictIndex, threshold: notifyThreshold)
                        })
                    .tabItem {
                        Label(LocalizedStringKey("nav-settings-string"), systemImage: "gear")
                    }
                }
                .onAppear {
                    // correct the transparency bug for Tab bars
                    let tabBarAppearance = UITabBarAppearance()
                    tabBarAppearance.configureWithDefaultBackground()
                    UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
                    // correct the transparency bug for Navigation bars
//                    let navigationBarAppearance = UINavigationBarAppearance()
//                    navigationBarAppearance.configureWithOpaqueBackground()
//                    UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
                    
                    // Validate and recover subscription state
                    NotificationManager.AWSManager.validateSubscriptionState()
                    
                    // Initialize location manager and set up auto-location callback
                    let locationManager = LocationManager.shared
                    locationManager.onLocationChanged = { cityIndex, districtIndex in
                        // Handle auto-location changes through the coordinated path
                        // This ensures @AppStorage is updated and prevents double subscriptions
                        DispatchQueue.main.async {
                            subscribedCityIndex = cityIndex
                            subscribedDistrictIndex = districtIndex
                            NotificationManager.setNotifyMode(
                                cityIndex: cityIndex, 
                                districtIndex: districtIndex, 
                                threshold: notifyThreshold
                            )
                        }
                    }
                }
            }
        }
    }
    
    
}

// MARK: Notification Handling -
// MARK: https://www.youtube.com/watch?v=TGOF8MqcAzY&ab_channel=DesignCode
// MARK: https://designcode.io/swiftui-advanced-handbook-push-notifications-part-2
class AppDelegate: NSObject, UIApplicationDelegate {
    @AppStorage("notifyThreshold") var notifyThreshold: NotifyThreshold = .eg3          // (duplicate)
//    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true                         // (duplicate)
    let SNSPlatformApplicationArn = AppConfig.platformApplicationArn(sandbox: TaiwanEEWApp.DEBUG)
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")
    func seperate(){ logger.debug(""); logger.debug("  -------- incoming notification --------")}       // for debugging only
    
    let gcmMessageIDKey = "gcm.message_id"

    
    // MARK: - Did Finish Launching
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UIApplication.shared.applicationIconBadgeNumber = 0

        // Migration: anyone already past first launch chose their region under the old
        // build, so mark onboarding complete. Without this the new subscription gate would
        // strand existing users with no district subscription.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "hasCompletedOnboarding") == nil,
           defaults.object(forKey: "isFirstLaunch") != nil,
           defaults.bool(forKey: "isFirstLaunch") == false {
            defaults.set(true, forKey: "hasCompletedOnboarding")
        }

        // Register BGTasks as early as possible (before returning from didFinishLaunching)
        LocationManager.registerBackgroundTasks()

        // Install App Check before configuring Firebase so every Firebase request carries an
        // attestation token. Registered but unenforced in the console for now — see
        // AppCheckProviderFactory for the enforcement rollout plan.
        AppCheck.setAppCheckProviderFactory(TaiwanEEWAppCheckProviderFactory())

        // Configure Firebase and FCM (to disable FCM notification (fuck FCM lmao
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        
        Messaging.messaging().deleteToken { error in
            if let error = error {
                self.logger.error("Error deleting FCM token: \(error.localizedDescription)")
            } else {
                self.logger.info("Successfully deleted FCM token")
            }
        }

        // For iOS 10 display notification (sent via APNS)
        UNUserNotificationCenter.current().delegate = self
        // Notification Authorization
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert]
        UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: {_, _ in })
        
        // Setup AWS Cognito credentials
        let credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: AWSRegionType.APNortheast1, identityPoolId: AppConfig.cognitoPoolID)

        let defaultServiceConfiguration = AWSServiceConfiguration(
            region: AWSRegionType.APNortheast1, credentialsProvider: credentialsProvider)

        AWSServiceManager.default().defaultServiceConfiguration = defaultServiceConfiguration

        UIApplication.shared.registerForRemoteNotifications()
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // Re-schedule background location updates if auto-location is enabled
        let locationManager = LocationManager.shared
        if locationManager.isAutoLocationEnabled {
            locationManager.scheduleBackgroundLocationUpdate()
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Ensure background location updates are scheduled
        let locationManager = LocationManager.shared
        if locationManager.isAutoLocationEnabled {
            locationManager.scheduleBackgroundLocationUpdate()
        }
    }

    // MARK: - Receive Notification
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

      if let messageID = userInfo[gcmMessageIDKey] {
        logger.debug("Message ID: \(String(describing: messageID))")
      }

      logger.debug("Notification payload: \(String(describing: userInfo))")

      completionHandler(UIBackgroundFetchResult.newData)
    }
    
    // MARK: - Did Register
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        UserDefaults.standard.set(token, forKey: "deviceTokenForSNS")
        logger.info("Registered for Apple Remote Notifications")
        logger.info("Device token (APNs): \(token)")
        
        // Set APNs for FCM
//        Messaging.messaging().setAPNSToken(deviceToken, type: .unknown)
        
        // Set APNs for AWS SNS
        // Create a platform endpoint. In this case,  the endpoint is a device endpoint ARN
        let sns = AWSSNS.default()
        let request = AWSSNSCreatePlatformEndpointInput()
        request?.token = token
        request?.platformApplicationArn = SNSPlatformApplicationArn
        sns.createPlatformEndpoint(request!).continueWith(executor: AWSExecutor.mainThread(), block: { (task: AWSTask!) -> AnyObject? in
            if task.error != nil {
                self.logger.error("SNS endpoint creation error: \(String(describing: task.error))")
            } else {
                let createEndpointResponse = task.result! as AWSSNSCreateEndpointResponse

                if let endpointArnForSNS = createEndpointResponse.endpointArn {
                    self.logger.info("SNS endpointArn: \(endpointArnForSNS)")
                    UserDefaults.standard.set(endpointArnForSNS, forKey: "endpointArnForSNS")
                    
                    // For Settings Display `/APNS/TaiwanEEW/<ARN>` (or `/APNS/TaiwanEEW/<ARN>` for development env)
                    UserDefaults.standard.set(endpointArnForSNS.replacingOccurrences(of: AppConfig.endpointArnPrefix, with: ""), forKey: "endpointArnSuffixForSNS")
                    
                    // Recover subscription state after endpoint is created
                    Task {
                        await NotificationManager.AWSManager.recoverSubscriptionState()
                    }
                }
            }

            return nil
        })
        
        // Validate subscription state and subscribe to version topic
        NotificationManager.AWSManager.validateSubscriptionState()
        
        // Subscribe to version topic
        Task {
            let currentVersion = NotificationManager.AWSManager.getCurrentVersion()
            logger.info("Current app version: \(currentVersion)")
            await NotificationManager.AWSManager.subscribeToVersionTopic()
        }
    }

    
    // MARK: - Failed to Register
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("Failed to register for Apple Remote Notifications")
        logger.error("Registration error: \(error.localizedDescription)")
    }
        
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {

      let deviceToken:[String: String] = ["token": fcmToken ?? ""]
        logger.debug("Device token (FCM): \(deviceToken)")                                  // This token can be used for testing notifications on FCM
    }
}

// MARK: Notification Functions
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {

  // Receive displayed notifications for iOS 10 devices.
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo

    // Print message ID and full message.
    if let messageID = userInfo[gcmMessageIDKey] {
        seperate()
        logger.debug("Message ID: \(String(describing: messageID))")
    }

    logger.debug("Notification payload: \(String(describing: userInfo))")

    // Change this to your preferred presentation option
    completionHandler([.banner, .badge, .sound])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo

    if let messageID = userInfo[gcmMessageIDKey] {
      logger.debug("Message ID from userNotificationCenter didReceive: \(String(describing: messageID))")
    }

    logger.debug("Notification payload: \(String(describing: userInfo))")

    // Permission-problem notifications deep link to this app's Settings page.
    if userInfo[NotificationManager.deepLinkKey] as? String == NotificationManager.deepLinkAppSettings {
        openAppSettings()
    }

    completionHandler()
  }

  /// Opens this app's page in iOS Settings. Called when the user taps a permission
  /// notification; the app is already active by the time a response is delivered.
  private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString),
          UIApplication.shared.canOpenURL(url) else {
      logger.error("Unable to open app settings URL")
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(url)
    }
  }
}

