//  Deprecated
//  EarthquakeReport.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/6/16.
//
// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let welcome = try? JSONDecoder().decode(Welcome.self, from: jsonData)

import Foundation

@available(*, deprecated, message: "Use new EqReport / EqReportDetailed model for ExpTech API support")
struct EarthquakeResponseCWA: Codable {
    let success: String
    let result: Result
    let records: Records
}

struct Result: Codable {
    let resource_id: String
    let fields: [Field]
}

struct Field: Codable {
    let id: String
    let type: String
}

struct Records: Codable {
    let datasetDescription: String
    let Earthquake: [Earthquake]
}

// MARK: - General Earthquake Information
struct Earthquake: Codable, Identifiable {
    var id: UUID { UUID() }                 // Unique identifier for ForEach loops
    let EarthquakeNo: Int                   // 地震編號
    let ReportType: String                  // “地震報告”
    let ReportColor: String                 // 4色：綠、黃（>M5.5, >4）、橘（>M6.0, >5-）、紅（>M6.5, >6-）
    let ReportContent: String               // "06/24-08:40花蓮縣近海發生規模4.0有感地震，最大震度花蓮縣太魯閣4級。"
    let ReportImageURI: String              // 正式報告圖檔網址
    let ReportRemark: String                // "本報告係中央氣象署地震觀測網即時地震資料地震速報之結果。"
    let Web: String                         // scweb.cwa.gov.tw 地震報告網頁網址
    let ShakemapImageURI: String?            // 等震度圖檔網址
    let EarthquakeInfo: EarthquakeInfo      // 詳細地震參數: 時間、深度、震央、規模
    let Intensity: Intensity                // 詳細地震報告：各地區之震度資訊
    
    var originDate: Date? {                 // 產生地震發震時間的 Date 物件，用於 ReportDispatcher 的 sorting
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: EarthquakeInfo.OriginTime)
    }
}

// MARK: - Earthquake Parameters
struct EarthquakeInfo: Codable {
    let OriginTime: String                  // yyyy-mm-dd HH:MM:SS
    let Source: String                      // "中央氣象署"
    let FocalDepth: Float                   // 深度
    let Epicenter: Epicenter                // 震央
    let EarthquakeMagnitude: EarthquakeMagnitude    // 規模
}

struct Epicenter: Codable {
    let Location: String                    // "花蓮縣政府北北東方  17.7  公里 (位於花蓮縣近海)"
    let EpicenterLatitude: Float            // Lat (y)
    let EpicenterLongitude: Float           // Lon (x)
}

struct EarthquakeMagnitude: Codable {
    let MagnitudeType: String               // ”芮氏規模“
    let MagnitudeValue: Float               // 規模
}

struct Intensity: Codable {
    let ShakingArea: [ShakingArea]          // 詳細地震報告：各地區之震度資訊
}

// MARK: - 以市區為單位的震度資訊
struct ShakingArea: Codable {
    let AreaDesc: String                    // 縣市名+"地區" OR "最大震度 ? 級地區"
    let CountyName: String                  // 縣市名       OR 縣市名列
    let InfoStatus: String?                 // "observe"
    let AreaIntensity: String               // AreaDesc 指定地區之最大震度
    let EqStation: [EqStation]              //市區單位內各測站震度資訊
}

// MARK: 市區單位內各測站震度資訊
struct EqStation: Codable {
    let pga: PGA?                           // PGA（三維、和）
    let pgv: PGV?                           // PGV（三維、和）
    let StationName: String                 // 測站名 "太魯閣" "西寶"
    let StationID: String                   // 測站代號 "XXX" or "XXXX"
    let InfoStatus: String?                  // "observe"
    let BackAzimuth: Float                  // 測站方位角
    let EpicenterDistance: Float            // 測站震央距離
    let SeismicIntensity: String            // 震度 "1級"
    let StationLatitude: Float              // 測站 Lat
    let StationLongitude: Float             // 測站 Lon
    let WaveImageURI: String?               // 測站震波圖檔網址
}

struct PGA: Codable {
    let unit: String                        // "gal"
    let EWComponent: Float                  // 東西分量
    let NSComponent: Float                  // 南北分量
    let VComponent: Float                   // 上下分量
    let IntScaleValue: Float                // 和
}

struct PGV: Codable {
    let unit: String                        // "kine"
    let EWComponent: Float                  // 東西分量
    let NSComponent: Float                  // 南北分量
    let VComponent: Float                   // 上下分量
    let IntScaleValue: Float                // 和
}

extension Earthquake {
    func getMaxIntensity() -> String? {
            let maxIntensity = self.Intensity.ShakingArea.compactMap { $0.AreaIntensity }.max()
        return maxIntensity?.replacingOccurrences(of: "級", with: "").replacingOccurrences(of: "弱", with: "-").replacingOccurrences(of: "強", with: "+")
    }
    
    func getLocationDesc() -> String? {
        let location = self.EarthquakeInfo.Epicenter.Location
        guard let startRange = location.range(of: "位於"),
              let endRange = location.range(of: ")") else {
            return nil
        }
        
        let startIndex = location.index(startRange.upperBound, offsetBy: 0)
        let endIndex = location.index(before: endRange.lowerBound)
        
        let result = location[startIndex...endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return String(result)
    }
}
