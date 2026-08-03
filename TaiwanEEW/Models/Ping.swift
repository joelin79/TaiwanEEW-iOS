//
//  Ping.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/7/31.
//

import Foundation

struct Ping: Identifiable, Codable {
    var id: String
    var pingTime: Date
    var status: Bool
}
