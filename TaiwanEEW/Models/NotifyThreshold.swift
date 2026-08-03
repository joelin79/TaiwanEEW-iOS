//
//  NotifyThreshold.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/6/19.
//

import Foundation
import SwiftUI

enum NotifyThreshold: String, CaseIterable, Identifiable, Codable {
    case off, eg0, eg1, eg2, eg3, eg4
    var id: Self {self}
    
    func getDisplayName() -> LocalizedStringKey {
        switch self {
        case .off:
            return LocalizedStringKey("off-string")
        case .eg0:
            return LocalizedStringKey("eg0-string")
        case .eg1:
            return LocalizedStringKey("eg1-string")
        case .eg2:
            return LocalizedStringKey("eg2-string")
        case .eg3:
            return LocalizedStringKey("eg3-string")
        case .eg4:
            return LocalizedStringKey("eg4-string")
        }
    }
    
    func getTopicKey() -> String {
        self.rawValue
    }
    
    func getIntValue() -> Int {
        switch self {
        case .eg0:
            return 0
        case .eg1:
            return 1
        case .eg2:
            return 2
        case .eg3:
            return 3
        case .eg4:
            return 4
        default:
            return -1
        }
    }
}
