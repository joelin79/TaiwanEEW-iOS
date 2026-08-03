//
//  EEWReport.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/3.
//

import Foundation

struct EEWReport: Identifiable, Codable {
    var id: UUID { UUID() }
    var depth: Double
    var description: String
    var epicenterLat: Double
    var epicenterLon: Double
    var event: String
    var identifier: String
    var language: String
    var magnitudeType: String
    var magnitudeValue: Double
    var msgNo: Int
    var msgType: String
    var originTime: Date
    var pgaAdj: Double
    var references: String
    var schemaVer: String
    var senderName: String
    var sent: Date
    var status: String
}
