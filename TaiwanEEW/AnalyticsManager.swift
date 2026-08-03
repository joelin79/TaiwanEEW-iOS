//
//  AnalyticsManager.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/9/7.
//

import SwiftUI
import FirebaseAnalytics
import FirebaseAnalyticsSwift
import os.log

final class AnalysicsManager {
    static let shared = AnalysicsManager()
    let debug = true
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AnalyticsManager")
    
    private init() { }
    
    func logEvent(name: String, params: [String:Any]? = nil) {
        Analytics.logEvent(name, parameters: params)
        if(debug){
            logger.debug("Firebase Analytics event: \(name), params: \(String(describing: params))")
        }
    }
    
    func setUserId(userId: String) {
        Analytics.setUserID(userId)
        if(debug){
            logger.debug("Firebase Analytics setUserId: \(userId)")
        }
    }
    
    func setUserProperty(value: String?, property: String) {
        Analytics.setUserProperty(value, forName: property)
        if(debug){
            logger.debug("Firebase Analytics setUserProperty: \(property) = \(String(describing: value))")
        }
    }
}
