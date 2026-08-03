//
//  LocationManager.swift
//  TaiwanEEW
//
//  Created by Auto Location Feature
//

import Foundation
import CoreLocation
import UserNotifications
import BackgroundTasks
import os.log

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private let notificationManager = NotificationManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LocationManager")

    // MARK: - Diagnostics Availability

    /// TestFlight and development builds carry a sandbox receipt; App Store builds do not.
    static var isTestFlightBuild: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// Location narration notifications are offered in debug and TestFlight builds only,
    /// never to App Store users.
    static var isDiagnosticsAvailable: Bool {
        TaiwanEEWApp.DEBUG || isTestFlightBuild
    }

    /// Defaults to on so testers see narration without hunting for the toggle first.
    private var isLocationNarrationEnabled: Bool {
        guard UserDefaults.standard.object(forKey: "locationNarrationEnabled") != nil else { return true }
        return UserDefaults.standard.bool(forKey: "locationNarrationEnabled")
    }

    /// iOS only offers the When-In-Use -> Always upgrade prompt once per permission grant,
    /// so only ask once. Cleared when the user resets the permission in iOS Settings.
    private var hasRequestedAlwaysUpgrade: Bool {
        get { UserDefaults.standard.bool(forKey: "hasRequestedAlwaysUpgrade") }
        set { UserDefaults.standard.set(newValue, forKey: "hasRequestedAlwaysUpgrade") }
    }

    private var lastPermissionReminderDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastPermissionReminderDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastPermissionReminderDate") }
    }

    // Callback to notify the main app of location changes
    var onLocationChanged: ((_ cityIndex: Int, _ districtIndex: Int) -> Void)?
    
    // Background task management
    private static let backgroundTaskIdentifier = "com.joedev.TaiwanEEW.locationUpdate"
    private var backgroundTask: BGTask?
    private let updateInterval: TimeInterval = 30 * 60 // 30 minutes
    private var lastLocationUpdate: Date?
    private var isStationary: Bool = false
    private var stationaryThreshold: TimeInterval = 10 * 60 // 10 minutes stationary detection
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isAutoLocationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoLocationEnabled, forKey: "autoLocationEnabled")
            if isAutoLocationEnabled {
                requestLocationPermission()
                scheduleBackgroundLocationUpdate()
            } else {
                stopLocationUpdates()
                cancelBackgroundLocationUpdate()
            }
        }
    }
    
    private override init() {
        self.isAutoLocationEnabled = UserDefaults.standard.bool(forKey: "autoLocationEnabled")
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // District-level accuracy
        locationManager.distanceFilter = 500 // Update every 500 meters minimum
        authorizationStatus = locationManager.authorizationStatus
        
        // Load last update time
        if let lastUpdate = UserDefaults.standard.object(forKey: "lastLocationUpdate") as? Date {
            lastLocationUpdate = lastUpdate
        }
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            // Handle permission denied
            sendPermissionNotification("位置權限被拒絕", "自動定位需要位置權限，請前往設定開啟。")
        @unknown default:
            break
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedAlways else {
            sendDebugNotification("位置權限不足", "需要「一律允許」權限才能啟用背景定位")
            return
        }
        
        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Start both continuous and significant location changes
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        sendDebugNotification("自動定位已啟用", "開始監控位置變化（包含背景更新）")
    }
    
    func stopLocationUpdates() {
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        sendDebugNotification("自動定位已停用", "停止監控位置變化")
    }
    
    func updateLocationManually() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestLocationPermission()
            return
        }
        
        locationManager.requestLocation()
    }
    
    // MARK: - District Matching
    
    func findClosestDistrict(to coordinate: CLLocationCoordinate2D) -> (cityIndex: Int, districtIndex: Int, distance: Double) {
        var closestDistance = Double.infinity
        var closestDistrict: (cityIndex: Int, districtIndex: Int) = (0, 0)
        
        for (cityIndex, city) in Location.cities.enumerated() {
            for (districtIndex, district) in city.district.enumerated() {
                let districtLocation = CLLocation(latitude: district.lat, longitude: district.lon)
                let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = userLocation.distance(from: districtLocation)
                
                if distance < closestDistance {
                    closestDistance = distance
                    closestDistrict = (cityIndex, districtIndex)
                }
            }
        }
        
        return (closestDistrict.cityIndex, closestDistrict.districtIndex, closestDistance)
    }
    
    private func updateSubscriptionForLocation(_ coordinate: CLLocationCoordinate2D) {
        let (cityIndex, districtIndex, distance) = findClosestDistrict(to: coordinate)
        
        // Get current subscribed location from UserDefaults
        let currentCityIndex = UserDefaults.standard.integer(forKey: "subscribedCityIndex")
        let currentDistrictIndex = UserDefaults.standard.integer(forKey: "subscribedDistrictIndex")
        
        // Check if location actually changed
        if cityIndex != currentCityIndex || districtIndex != currentDistrictIndex {
            let cityName = Location.cities[cityIndex].getDisplayName()
            let districtName = Location.cities[cityIndex].district[districtIndex].districtName
            
            // Notify the main app to handle the location change through the coordinated path
            // This ensures @AppStorage variables are updated and subscription is handled properly
            onLocationChanged?(cityIndex, districtIndex)
            
            // Send debug notification
            let distanceKm = String(format: "%.1f", distance / 1000)
            sendDebugNotification(
                "自動切換通知區域",
                "已切換至：\(districtName) (距離 \(distanceKm) 公里)"
            )
            
            logger.info("Auto-location updated: \(String(describing: cityName)) \(districtName) (distance: \(distanceKm) km)")
        } else {
            let distanceKm = String(format: "%.1f", distance / 1000)
            logger.debug("Location unchanged: Still in same district (distance: \(distanceKm) km)")
        }
    }
    
    // MARK: - Background Task Management
    
    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            guard let appTask = task as? BGAppRefreshTask else {
                LocationManager.shared.logger.error("Unexpected BGTask type for identifier: \(type(of: task))")
                // Ensure we try again later rather than silently dropping future updates
                LocationManager.shared.scheduleBackgroundLocationUpdate()
                task.setTaskCompleted(success: false)
                return
            }
            LocationManager.shared.handleBackgroundLocationUpdate(task: appTask)
        }
    }
    
    func scheduleBackgroundLocationUpdate() {
        // Cancel any existing requests
        cancelBackgroundLocationUpdate()
        
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: updateInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background location update scheduled for: \(request.earliestBeginDate?.formatted() ?? "unknown")")
        } catch {
            logger.error("Failed to schedule background location update: \(error.localizedDescription)")
            sendDebugNotification("背景更新排程失敗", error.localizedDescription)
        }
    }
    
    private func cancelBackgroundLocationUpdate() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)
    }
    
    func handleBackgroundLocationUpdate(task: BGAppRefreshTask) {
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Schedule next update
        scheduleBackgroundLocationUpdate()
        
        // Check if we need to update location
        let now = Date()
        if let lastUpdate = lastLocationUpdate {
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate < updateInterval && !shouldForceUpdate() {
                logger.debug("Background update skipped: Too soon since last update")
                task.setTaskCompleted(success: true)
                return
            }
        }
        
        // Perform location update
        Task {
            await performBackgroundLocationUpdate()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func shouldForceUpdate() -> Bool {
        // Force update if user has moved significantly or after app restart
        guard let last = lastLocationUpdate else { return true }
        return Date().timeIntervalSince(last) > (updateInterval * 2)
    }
    
    private func performBackgroundLocationUpdate() async {
        guard isAutoLocationEnabled && authorizationStatus == .authorizedAlways else {
            return
        }
        
        // Get current location
        locationManager.requestLocation()
        
        // Update timestamp
        lastLocationUpdate = Date()
        UserDefaults.standard.set(lastLocationUpdate, forKey: "lastLocationUpdate")
        
        sendDebugNotification("背景定位更新", "已在背景執行位置檢查")
    }
    
    // MARK: - Movement Detection
    
    private func detectStationaryBehavior(newLocation: CLLocation) {
        guard let lastLocation = currentLocation else {
            isStationary = false
            return
        }
        
        let distance = newLocation.distance(from: lastLocation)
        let timeInterval = newLocation.timestamp.timeIntervalSince(lastLocation.timestamp)
        
        // Consider stationary if moved less than 100m in 10+ minutes
        if distance < 100 && timeInterval > stationaryThreshold {
            if !isStationary {
                isStationary = true
                // Reduce location accuracy when stationary to save battery
                locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
                sendDebugNotification("偵測到靜止狀態", "已降低定位精度以節省電力")
            }
        } else {
            if isStationary {
                isStationary = false
                // Restore normal accuracy when moving
                locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
                sendDebugNotification("偵測到移動", "已恢復正常定位精度")
            }
        }
    }
    
    // MARK: - Debug Notifications
    
    /// Diagnostic narration of location events. Debug/TestFlight only, and only when the
    /// tester has left the Settings toggle on.
    private func sendDebugNotification(_ title: String, _ body: String) {
        // Only send debug notifications if auto-location is enabled
        guard isAutoLocationEnabled else { return }
        guard Self.isDiagnosticsAvailable, isLocationNarrationEnabled else { return }

        notificationManager.push(title, body)
    }

    /// Permission problems are real user-facing problems - auto-location silently does
    /// nothing without "Always", so these must reach App Store users too, not just debug
    /// builds. Rate limited to once a day in production because didChangeAuthorization
    /// fires on every launch and would otherwise nag; testers see it every time.
    private func sendPermissionNotification(_ title: String, _ body: String) {
        guard isAutoLocationEnabled else { return }

        if !Self.isDiagnosticsAvailable,
           let last = lastPermissionReminderDate,
           Date().timeIntervalSince(last) < 24 * 60 * 60 {
            logger.debug("Permission reminder suppressed (already sent within 24h)")
            return
        }
        lastPermissionReminderDate = Date()

        // Tapping takes the user straight to the app's Settings page - the notification
        // asks them to change a permission, so it should hand them the place to do it.
        notificationManager.push(title, body, opensAppSettings: true)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Detect stationary behavior for battery optimization
        detectStationaryBehavior(newLocation: location)
        
        currentLocation = location
        
        // Update subscription based on new location
        updateSubscriptionForLocation(location.coordinate)
        
        // Update last location update timestamp
        lastLocationUpdate = Date()
        UserDefaults.standard.set(lastLocationUpdate, forKey: "lastLocationUpdate")
        
        logger.info("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location manager failed with error: \(error.localizedDescription)")
        sendDebugNotification("定位失敗", error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedAlways:
            // Permission is healthy again - let a future downgrade remind immediately.
            lastPermissionReminderDate = nil
            if isAutoLocationEnabled {
                startLocationUpdates()
            }
        case .authorizedWhenInUse:
            guard isAutoLocationEnabled else { break }
            // iOS only grants "Always" as an upgrade from "When In Use", so ask for the
            // upgrade here rather than leaving the user to discover it in Settings.
            if !hasRequestedAlwaysUpgrade {
                hasRequestedAlwaysUpgrade = true
                logger.info("Requesting upgrade to Always authorization")
                locationManager.requestAlwaysAuthorization()
            } else {
                sendPermissionNotification("需要「一律允許」位置權限", "自動定位需要「一律允許」才能在背景更新通知區域，請前往設定開啟。")
            }
        case .denied, .restricted:
            // Deliberately leave isAutoLocationEnabled on: the Settings screen shows a
            // "go to Settings" action while it is enabled, which is how the user recovers.
            sendPermissionNotification("位置權限被拒絕", "自動定位需要位置權限，請前往設定開啟。")
        case .notDetermined:
            // The user reset the permission in iOS Settings ("Ask Next Time"), so the
            // system will offer the Always upgrade prompt again - allow us to ask again.
            hasRequestedAlwaysUpgrade = false
        @unknown default:
            break
        }
    }
}
