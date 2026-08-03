//
//  File.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/3.
//

import Foundation
import os.log

class EEWService {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "EEWService")
    
    static func pTime(focalDepth: Double, dist: Double) -> Double {
        let ZA = focalDepth
        let XB = dist
        let (G0, G): (Double, Double)
        
        if focalDepth <= 40 {
            G0 = 5.10298
            G = 0.06659
        } else {
            G0 = 7.804799
            G = 0.004573
        }
        
        let Zc = -1 * (G0 / G)
        let Xc = (pow(XB, 2) - 2*(G0/G)*ZA - pow(ZA, 2)) / (2*XB)
        
        var Theta_A = atan((ZA-Zc)/Xc)
        if Theta_A < 0 {
            Theta_A += .pi
        }
        Theta_A = .pi - Theta_A
        let Theta_B = atan(-1 * Zc / (XB - Xc))
        return ((1/G) * log(tan((Theta_A/2)) / tan((Theta_B/2))))
    }
    
    static func sTime(focalDepth: Double, dist: Double) -> Double {
        let ZA = focalDepth
        let XB = dist
        var G0: Double
        var G: Double
        
        if focalDepth <= 40 {
            G0 = 5.10298
            G = 0.06659
        } else {
            G0 = 7.804799
            G = 0.004573
        }
        
        G0 /= 1.732
        G /= 1.732
        
        let Zc = -1 * (G0 / G)
        let Xc = (pow(XB, 2) - 2*(G0/G)*ZA - pow(ZA, 2)) / (2*XB)
        
        var Theta_A = atan((ZA-Zc)/Xc)
        if Theta_A < 0 {
            Theta_A += .pi
        }
        Theta_A = .pi - Theta_A
        let Theta_B = atan(-1 * Zc / (XB - Xc))
        return ((1/G) * log(tan((Theta_A/2)) / tan((Theta_B/2))))
    }
    
    static func getPDistance(e: EventDispatcher) -> Double {
        let distance = EEWService.dist(latA: e.latA, lonA: e.lonA, latB: e.latB, lonB: e.lonB)
        let pTime = EEWService.pTime(focalDepth: e.depth, dist: distance)
        let dx = distance * 1000 / pTime
        let timePast = Date().timeIntervalSince(e.originTime)
        logger.debug("P wave radius: \(dx * timePast) meters")
        return dx * timePast
    }
    
    static func getSDistance(e: EventDispatcher) -> Double {
        let distance = EEWService.dist(latA: e.latA, lonA: e.lonA, latB: e.latB, lonB: e.lonB)
        let pTime = EEWService.sTime(focalDepth: e.depth, dist: distance)
        let dx = distance * 1000 / pTime
        let timePast = Date().timeIntervalSince(e.originTime)
        logger.debug("S wave radius: \(dx * timePast) meters")
        return dx * timePast
    }
    
    // countdown time
    static func minusTime(focalDepth: Double, dist: Double, plusTime: Int) -> Double {
        return sTime(focalDepth: focalDepth, dist: dist) - Double(plusTime)
    }
    
    // time gap between earthquake origin time and sent time
    static func plusTime (originTime: Date, sentTime: Date) -> Int {
        return Int(sentTime.timeIntervalSince(originTime))
    }
        
    static func pgaToIntensity(pga: Double) -> String {
        switch pga {
        case ..<0.8: return "0"
        case 0.8..<2.5: return "1"
        case 2.5..<8.0: return "2"
        case 8.0..<25.0: return "3"
        case 25.0..<80.0: return "4"
        case 80.0..<140.0: return "5-"
        case 140.0..<250.0: return "5+"
        case 250.0..<400.0: return "6-"
        case 400.0..<800.0: return "6+"
        default: return "7"
        }
    }
    
    static func intensityValueToString(int: Int) -> String {
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
    
    static func intensityStringToValue(str: String) -> Int {
        switch str {
        case "1", "2", "3", "4":
            return Int(str) ?? 0
        case "5-":
            return 5
        case "5+":
            return 6
        case "6-":
            return 7
        case "6+":
            return 8
        case "7":
            return 9
        default:
            return 0
        }
    }
    
    static func pga(ML: Double, depth: Double, dist: Double, Si: Double, Padj: Double) -> Double {
        let rad = sqrt(pow(dist, 2) + pow(depth, 2))
        return (1.657 * exp(1.533*ML) * pow(rad, -1.607) * Si * Padj)
    }
    
    static func dist(latA: Double, lonA: Double, latB: Double, lonB: Double) -> Double {
        let avlat = 0.5 * (latA + latB)
        let a = 1.840708 + avlat * (0.0015269 + avlat * (-0.00034 + avlat * (1.02337e-6)))
        let b = 1.843404 + avlat * (-6.93799e-5 + avlat * (8.79993e-6 + avlat * (-6.47527e-8)))
        let dlat = latB - latA
        let dlon = lonB - lonA
        let dx = a * dlon * 60.0
        let dy = b * dlat * 60.0
        return sqrt(dx*dx + dy*dy)
    }
}
