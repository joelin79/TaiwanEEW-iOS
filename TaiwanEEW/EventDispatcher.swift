//
//  EventDispatcher.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/8/18.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Firebase
import SwiftUI
import os.log

class EventDispatcher: ObservableObject{
    @Binding var subscribedCityIndex: Int
    @Binding var subscribedDistrictIndex: Int
    @Published private(set) var ping: [Ping] = []
    @Published private(set) var lastPingTime: Date = Date(timeIntervalSince1970: 0)
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "EventDispatcher")
    
    // All displayed stats here
    @Published private(set) var event: [EEWReport] = []     // will be used in maps TODO: replace with this in AlertMapView
    @Published private(set) var originTime: Date = Date(timeIntervalSince1970: 0)
    @Published private(set) var publishedTime: Date = Date(timeIntervalSince1970: 0)
    @Published private(set) var arrivalTime: Date = Date(timeIntervalSince1970: 0)
    @Published private(set) var maxIntensityValue: Int = 0
    @Published private(set) var maxIntensity: String = "0"
    @Published private(set) var intensity: String = "0"
    @Published private(set) var eqSeq: Int = 0
    @Published private(set) var magnitude: Double = 0
    @Published private(set) var depth: Double = 0
    @Published private(set) var lonA: Double
    @Published private(set) var latA: Double
    @Published private(set) var si: Double
    
    @Published private(set) var lonB: Double = 0
    @Published private(set) var latB: Double = 0
    @Published private(set) var pgaAdj: Double = 0
    
    
    let db = Firestore.firestore()
    
    init(subscribedCityIndex: Binding<Int>, subscribedDistrictIndex: Binding<Int>) {
        self._subscribedCityIndex = subscribedCityIndex
        self._subscribedDistrictIndex = subscribedDistrictIndex
        self.lonA = Location.cities[subscribedCityIndex.wrappedValue].district[subscribedDistrictIndex.wrappedValue].lon
        self.latA = Location.cities[subscribedCityIndex.wrappedValue].district[subscribedDistrictIndex.wrappedValue].lat
        self.si = Location.cities[subscribedCityIndex.wrappedValue].district[subscribedDistrictIndex.wrappedValue].si
        getEvents()
    }
    
    func findMaxIntensity(e: EEWReport) -> (stringRepresentation: String, intRepresentation: Int) {
        var max = 0
        
        for city in Location.cities {
            for district in city.district {
                let intensity = EEWService.pgaToIntensity(pga: EEWService.pga(ML: e.magnitudeValue, depth: e.depth, dist: EEWService.dist(latA: district.lat, lonA: district.lon, latB: e.epicenterLat, lonB: e.epicenterLon), Si: district.si, Padj: e.pgaAdj))
                
                var int = 0
                        
                switch intensity {
                case "1", "2", "3", "4":
                    int = Int(intensity)!
                case "5-":
                    int = 5
                case "5+":
                    int = 6
                case "6-":
                    int = 7
                case "6+":
                    int = 8
                case "7":
                    int = 9
                default:
                    int = 0
                }
                
                if int > max {
                    max = int
                }
                
            }
        }
        
        logger.debug("Maximum intensity calculated: \(max)")
        
        switch max {
        case 1, 2, 3, 4:
            return (max.formatted(), max)
        case 5:
            return ("5-", max)
        case 6:
            return ("5+", max)
        case 7:
            return ("6-", max)
        case 8:
            return ("6+", max)
        case 9:
            return (7.formatted(), max)
        default:
            return ("未知", 0)
        }
    }
    
    func getEvents(){
        
        // listening the collection of the selected location
        // TODO: limit data read numbers
        db.collection("EEW").order(by: "sent", descending: true).limit(to: 1).addSnapshotListener { querySnapshot, error in
            
            // fetch documents into the "documents" array
            guard let documents = querySnapshot?.documents else {
                self.logger.error("Error fetching EEW documents: \(String(describing: error))")
                return
            }
            
            // then decode documents into a compactMap of type Event array, and store into event
            self.event = documents.compactMap { document -> EEWReport? in
                do {
                    return try document.data(as: EEWReport.self)
                } catch {
                    self.logger.error("Error decoding EEW document: \(error.localizedDescription)")
                    return nil
                }
            }
            
            // sort Event by `sent` (sent time)
            self.event.sort { $0.sent < $1.sent }
            
            // set variables
            if let e = self.event.last,
                let arrivalTime = Calendar.current.date(
                    byAdding: .second,
                    value: Int(EEWService.sTime(focalDepth: e.depth, dist: EEWService.dist(latA: self.latA, lonA: self.lonA, latB: e.epicenterLat, lonB: e.epicenterLon))),
                    to: e.originTime)
            {
                self.arrivalTime = arrivalTime
                self.publishedTime = e.sent
                self.intensity = EEWService.pgaToIntensity(pga: EEWService.pga(ML: e.magnitudeValue, depth: e.depth, dist: EEWService.dist(latA: self.latA, lonA: self.lonA, latB: e.epicenterLat, lonB: e.epicenterLon), Si: self.si, Padj: e.pgaAdj))
                self.eqSeq = e.msgNo
                self.magnitude = e.magnitudeValue
                self.depth = e.depth
                self.originTime = e.originTime
                self.lonB = e.epicenterLon
                self.latB = e.epicenterLat
                self.pgaAdj = e.pgaAdj
                (self.maxIntensity, self.maxIntensityValue) = self.findMaxIntensity(e: e)
            }
        }
        
        getPings()
    }
    
    func getPings(){
        
        // listening the collection of the selected location
        db.collection("ping")
            .order(by: "pingTime", descending: true)
            .limit(to: 2)
            .addSnapshotListener { querySnapshot, error in
            
            // fetch documents into the "documents" array
            guard let documents = querySnapshot?.documents else {
                self.logger.error("Error fetching Ping documents: \(String(describing: error))")
                return
            }
            
            // then decode documents into a compactMap of type Ping array, and store into event
            self.ping = documents.compactMap { document -> Ping? in
                do {
                    return try document.data(as: Ping.self)
                } catch {
                    self.logger.error("Error decoding Ping document: \(error.localizedDescription)")
                    return nil
                }
            }
            
            // sort Ping by eventTime
            self.ping.sort { $0.pingTime < $1.pingTime }
            
            // set variables
            if let lastPing = self.ping.last
            {
                self.lastPingTime = lastPing.pingTime
            }
        }
    }
    
//    func sendMessage(text: String) {
//        do {
//            let newMessage = Message(id: "\(UUID())", text: text, received: false, timestamp: Date())
//            try db.collection("messages").document().setData(from: newMessage)
//        } catch {
//            logger.error("Error adding message to Firestore: \(error.localizedDescription)")
//        }
//    }
    
}
