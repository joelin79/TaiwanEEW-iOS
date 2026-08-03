//
//  EqReport.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/13.
//

import Foundation

struct EqReport: Codable, Identifiable {
    let id: String
    let lat: Double
    let lon: Double
    let depth: Double
    let loc: String
    let mag: Double
    let time: Int
    let trem: Int
    let int: Int        // 5-: 5, 5+: 6, 6-: 7, 6+: 8, 7: 9
    let md5: String
    
    func getEqNumber() -> Int {
        return Int(id.prefix(6).suffix(3)) ?? 0
    }
    
    func getMaxIntensity() -> String? {
        switch int {
        case 1, 2, 3, 4:
            return int.formatted()
        case 5:
            return "5-"
        case 6:
            return "5+"
        case 7:
            return "6-"
        case 8:
            return "6+"
        case 9:
            return 7.formatted()
        default:
            return "未知"
        }
    }
    
    func getLocationDesc() -> String? {
        let location = loc
        guard let startRange = location.range(of: "位於"),
              let endRange = location.range(of: ")") else {
            return nil
        }
        
        let startIndex = location.index(startRange.upperBound, offsetBy: 0)
        let endIndex = location.index(before: endRange.lowerBound)
        
        let result = location[startIndex...endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return String(result)
    }
    
    func getDate() -> Date {
        return Date(timeIntervalSince1970: TimeInterval(time/1000))
    }
}

struct EqReportDetailed: Codable {
    let id: String
    let lat: Double
    let lon: Double
    let depth: Double
    let loc: String
    let mag: Double
    let time: Int64
    let list: [String: County]
    let trem: Int
    
    func getEqNumber() -> Int {
        return Int(id.prefix(6).suffix(3)) ?? 0
    }
    
    func getMaxIntensity() -> String? {
        // Find the maximum intensity value from the County instances
        let maxIntensity = list.values.map { $0.int }.max()
        
        guard let maxIntensity = maxIntensity else {
            return nil
        }

        return String(maxIntensity)
            .replacingOccurrences(of: "級", with: "")
            .replacingOccurrences(of: "弱", with: "-")
            .replacingOccurrences(of: "強", with: "+")
    }
    
    func getLocationDesc() -> String? {
        let location = loc
        guard let startRange = location.range(of: "位於"),
              let endRange = location.range(of: ")") else {
            return nil
        }
        
        let startIndex = location.index(startRange.upperBound, offsetBy: 0)
        let endIndex = location.index(before: endRange.lowerBound)
        
        let result = location[startIndex...endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return String(result)
    }
    
    func getDate() -> Date {
        return Date(timeIntervalSince1970: TimeInterval(time/1000))
    }

    struct County: Codable {
        let int: Int
        let town: [String: Town]

        struct Town: Codable {
            let lat: Double
            let lon: Double
            let int: Int
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, lat, lon, depth, loc, mag, time, list, trem
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        lat = try container.decode(Double.self, forKey: .lat)
        lon = try container.decode(Double.self, forKey: .lon)
        depth = try container.decode(Double.self, forKey: .depth)
        loc = try container.decode(String.self, forKey: .loc)
        mag = try container.decode(Double.self, forKey: .mag)
        time = try container.decode(Int64.self, forKey: .time)
        list = try container.decode([String: County].self, forKey: .list)
        trem = try container.decode(Int.self, forKey: .trem)
    }
    
    init(id: String, lat: Double, lon: Double, depth: Double, loc: String, mag: Double, time: Int64, list: [String: County], trem: Int) throws {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.depth = depth
        self.loc = loc
        self.mag = mag
        self.time = time
        self.list = list
        self.trem = trem
    }
}

/* Usage

// To list all counties
func listAllCounties(from earthquakeData: EarthquakeData) -> [String] {
    return Array(earthquakeData.list.keys)
}


*/
