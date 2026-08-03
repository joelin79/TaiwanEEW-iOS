//
//  TimeRange.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/4/11.
//

import Foundation
import SwiftUI

enum TimeRange: String, CaseIterable, Identifiable, Codable{
    case week, twoweek, month, sixmonth, year, all
    var id: Self { self }
    
    func getDisplayName() -> LocalizedStringKey {
        switch self {
        case .week:
            return LocalizedStringKey("week-string")
        case .twoweek:
            return LocalizedStringKey("twoweek-string")
        case .month:
            return LocalizedStringKey("month-string")
        case .sixmonth:
            return LocalizedStringKey("sixmonth-string")
        case .year:
            return LocalizedStringKey("year-string")
        case .all:
            return LocalizedStringKey("all-string")
        }
    }
    
    func getDays() -> Int {
        switch self {
        case .week:
            return 7
        case .twoweek:
            return 14
        case .month:
            return 31
        case .sixmonth:
            return 183
        case .year:
            return 365
        case .all:
            return 9999
        }
    }
}
