//
//  Event.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/8/19.
//

import Foundation

struct Event: Identifiable, Codable {
    var id: String
    var intensity: String
    var seconds: Int
    var eventTime: Date
}
