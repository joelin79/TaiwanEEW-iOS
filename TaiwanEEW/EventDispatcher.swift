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
    
    private var eewListener: ListenerRegistration?
    private var pingListener: ListenerRegistration?

    /// - Parameter startListening: previews pass false so opening a canvas does not attach
    ///   live Firestore listeners. Defaults to true so the feed can never be left off by
    ///   forgetting to start it — silence is this object's worst failure mode.
    init(cityIndex: Int, districtIndex: Int, startListening: Bool = true) {
        let coordinates = Self.coordinates(cityIndex: cityIndex, districtIndex: districtIndex)
        self.lonA = coordinates.lon
        self.latA = coordinates.lat
        self.si = coordinates.si
        if startListening {
            getEvents()
        }
    }

    /// Reads the subscribed district straight from UserDefaults, so the app can own one
    /// long-lived dispatcher without threading bindings through its initialiser.
    convenience init() {
        let defaults = UserDefaults.standard
        self.init(cityIndex: defaults.integer(forKey: "subscribedCityIndex"),
                  districtIndex: defaults.integer(forKey: "subscribedDistrictIndex"))
    }

    deinit {
        eewListener?.remove()
        pingListener?.remove()
    }

    /// Falls back to the first district rather than trapping. An index pair that no longer
    /// resolves — stale defaults, or a district removed from the table — would otherwise
    /// crash on launch, and a wrong region is recoverable where a crash is not.
    private static func coordinates(cityIndex: Int, districtIndex: Int) -> (lon: Double, lat: Double, si: Double) {
        let city = Location.cities.indices.contains(cityIndex) ? Location.cities[cityIndex] : Location.cities[0]
        let district = city.district.indices.contains(districtIndex) ? city.district[districtIndex] : city.district[0]
        return (district.lon, district.lat, district.si)
    }

    /// Repoints the intensity maths at a new district.
    ///
    /// Previously this happened by the whole object being rebuilt, which is what made the
    /// leaked listeners hard to spot: the rebuild was load-bearing rather than incidental.
    func updateDistrict(cityIndex: Int, districtIndex: Int) {
        let coordinates = Self.coordinates(cityIndex: cityIndex, districtIndex: districtIndex)
        guard coordinates.lon != lonA || coordinates.lat != latA || coordinates.si != si else { return }
        lonA = coordinates.lon
        latA = coordinates.lat
        si = coordinates.si
        logger.info("District changed - recomputing against the new reference point")
    }

    /// Reattaches the earthquake listener, for when the collection underneath it changes.
    func restartEventListener() {
        eewListener?.remove()
        eewListener = nil
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
    
    /// Which collection the alert feed reads from.
    ///
    /// Debug and TestFlight builds can point it at a separate collection so a drill can be
    /// staged without writing anything into the live one. The diagnostics check is not
    /// only about hiding the toggle: UserDefaults survives replacing a TestFlight install
    /// with an App Store one, so without it a tester who left the switch on could end up
    /// with a release build quietly watching test data and showing no real earthquakes.
    static var eewCollectionName: String {
        guard LocationManager.isDiagnosticsAvailable else { return "EEW" }
        return UserDefaults.standard.bool(forKey: "useTestEEWData") ? "EEW-test" : "EEW"
    }

    func getEvents(){

        // listening the collection of the selected location
        // TODO: limit data read numbers
        let collectionName = Self.eewCollectionName
        logger.info("Listening to EEW collection: \(collectionName)")
        // Held so it can be detached. Combined with the weak capture below this is what
        // lets the object deallocate at all: Firestore retains the closure, so a strong
        // self here kept every dispatcher alive for the life of the process.
        eewListener = db.collection(collectionName).order(by: "sent", descending: true).limit(to: 1).addSnapshotListener { [weak self] querySnapshot, error in
            guard let self else { return }

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
        pingListener?.remove()
        pingListener = db.collection("ping")
            .order(by: "pingTime", descending: true)
            .limit(to: 2)
            .addSnapshotListener { [weak self] querySnapshot, error in
            guard let self else { return }

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
