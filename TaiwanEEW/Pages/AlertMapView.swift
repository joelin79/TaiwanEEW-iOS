//
//  AlertMapView.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/5.
//
// reference:
// UIKit component implementation https://medium.com/@seanlinsanity/integrate-uikit-view-into-swiftui-view-34d0ce0296d8
// MK stuff https://www.youtube.com/watch?v=B0YnIOER8MI&list=PL23Revp-82LJw1dxVR9-6byAQXGPPeTum&index=5
// OpenStreetMap MapKit replacement https://www.kodeco.com/9697133-advanced-mapkit-tutorial-custom-mapkit-tiles

import SwiftUI
import MapKit
import os.log

struct AlertMapView: View {
    let taiwan = CLLocationCoordinate2D(latitude: 23.69484955415681, longitude: 120.96082538424629)
    @ObservedObject var eventManager: EventDispatcher
    @StateObject private var headingProvider = HeadingProvider()

    var body: some View {
        CustomMapView(eventManager: eventManager, headingProvider: headingProvider)
            // The magnetometer runs only while the map is on screen — switching tabs or
            // backgrounding stops it rather than leaving it spinning for a cone nobody
            // is looking at.
            .onAppear { headingProvider.start() }
            .onDisappear { headingProvider.stop() }
    }
}

private struct CustomMapView: UIViewRepresentable {
    typealias UIViewType = MKMapView
    @ObservedObject var eventManager: EventDispatcher
    /// Observed so a permission change redraws the view and updateUIView can turn the
    /// user's dot on without the app being relaunched.
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject var headingProvider: HeadingProvider
    @State private var userTrackingMode: MKUserTrackingMode = .none
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CustomMapView")

    let mapView = MKMapView()

    /// Only ask MapKit for the user's dot once permission is already granted. Setting
    /// showsUserLocation while the status is still .notDetermined can make MapKit raise
    /// the location prompt itself, which would appear unannounced on the alert screen
    /// rather than where the app actually explains why it wants location.
    private var canShowUserLocation: Bool {
        LocationPermissionStatus(status: locationManager.authorizationStatus).canFetchLocation
    }

    // MARK: - Make Map View
    func makeUIView(context: Context) -> MKMapView {
        setupRegionForMap(mapView)
        //        setupMapBoundary(mapView)
        
        // Disable user interaction
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // Add empty tile overlay
        //        let emptyTileOverlay = MKTileOverlay()
        //        emptyTileOverlay.canReplaceMapContent = true
        //        mapView.addOverlay(emptyTileOverlay, level: .aboveLabels)
        
        // Configure map to hide points of interest and city labels
        if #available(iOS 16.0, *) {
            let configuration = MKStandardMapConfiguration()
            configuration.pointOfInterestFilter = .excludingAll
            configuration.showsTraffic = false
            mapView.preferredConfiguration = configuration
        }
        
        // Set map type to muted standard to remove satellite imagery
        mapView.mapType = .standard

        // The standard blue dot. MapKit draws it because the delegate returns nil for any
        // annotation that is not the epicenter, MKUserLocation included.
        mapView.showsUserLocation = canShowUserLocation

        // Set the delegate
        mapView.delegate = context.coordinator
        
        // Add overlays in the correct order
        addOverlaysInOrder(to: mapView)
        
        // Start the timer to update circle radii
        context.coordinator.mapView = mapView
        
        return mapView
    }
    
    // MARK: - Update Map View
    func updateUIView(_ uiView: MKMapView, context: Context) {

        // Outside the event check below on purpose: that branch only runs when an
        // earthquake arrives, so leaving this inside it would mean a user who grants
        // location permission sees no dot until the next quake.
        if uiView.showsUserLocation != canShowUserLocation {
            uiView.showsUserLocation = canShowUserLocation
            if !canShowUserLocation {
                context.coordinator.removeHeadingAnnotation(from: uiView)
            }
        }

        context.coordinator.apply(heading: canShowUserLocation ? headingProvider.heading : nil)

        // Check if the event identifier has changed
        if context.coordinator.lastEventIdentifier != eventManager.event.last?.identifier {
            if (Date().timeIntervalSince(self.eventManager.originTime) < 120) {
                context.coordinator.startCircleUpdateTimer()
            } else {
                context.coordinator.stopCircleUpdateTimer()
            }
            logger.debug("Event identifier changed. Updating dynamic overlays...")
            
            // Update the colors of existing overlays
            for overlay in uiView.overlays {
                if let renderer = uiView.renderer(for: overlay) as? MKOverlayPathRenderer {
                    if let title = overlay.title, ((title?.starts(with: "dynamic_")) != nil) {
                        renderer.fillColor = context.coordinator.fillColor(for: title!)
                    }
                }
            }
            
            // Remove and re-add epicenter annotation and circles
            uiView.removeAnnotations(uiView.annotations.filter { $0.title == "Epicenter" })
            uiView.removeOverlays(uiView.overlays.filter { $0.title == "YellowCircle" || $0.title == "RedCircle" })
            addEpicenterAnnotationAndCircles(to: uiView)
            
            // Update the last event identifier
            context.coordinator.lastEventIdentifier = eventManager.event.last?.identifier
            
            if eventManager.latB != 0 {
                setupRegionForMap(uiView)
            }
        }
    }
    
    func makeCoordinator() -> MapCoordinator {
        MapCoordinator(eventManager: eventManager)
    }
    
    private func setupRegionForMap(_ mapView: MKMapView) {
        
        // The default map range. iPhone with the lat - 1 to center on screen.
        var lat: Double
        var lon: Double
        if Device.deviceType == .iphone {
            lat = eventManager.latB == 0 ? 22.95723 : eventManager.latB - 1
            lon = 120.82812 // 南投
        } else {
            lat = eventManager.latB == 0 ? 22.95723 : min(eventManager.latB, 23.75)
            lon = 121.32664 // 光復鄉
        }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2DMake(lat, lon),
            span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
        )
        mapView.setRegion(region, animated: true)
    }
    
    //    private func setupMapBoundary(_ mapView: MKMapView) {
    //        // Define the bounding coordinates for Taiwan
    //        let northEast = CLLocationCoordinate2D(latitude: 25.3, longitude: 122.0)
    //        let southWest = CLLocationCoordinate2D(latitude: 21.9, longitude: 120.0)
    //
    //        // Create a coordinate region from the bounding coordinates
    //        let boundingRegion = MKCoordinateRegion(
    //            center: CLLocationCoordinate2D(
    //                latitude: (northEast.latitude + southWest.latitude) / 2,
    //                longitude: (northEast.longitude + southWest.longitude) / 2
    //            ),
    //            span: MKCoordinateSpan(
    //                latitudeDelta: northEast.latitude - southWest.latitude,
    //                longitudeDelta: northEast.longitude - southWest.longitude
    //            )
    //        )
    //
    //        // Create a map camera boundary and set it to the map view
    //        let boundary = MKMapView.CameraBoundary(coordinateRegion: boundingRegion)
    //        mapView.cameraBoundary = boundary
    //
    //        // Set zoom range (optional, adjust as needed)
    //        let zoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 50000,
    //                                                  maxCenterCoordinateDistance: 2500000)
    //        mapView.cameraZoomRange = zoomRange
    //    }
    
    private func addOverlaysInOrder(to mapView: MKMapView) {
        
        // Add map patch if device is under iOS 18 (experiencing map hole bug)
        if #unavailable(iOS 18) {
            self.addPatchPolygon(to: mapView)
        }
        
        //        parseStaticAsiaGeoJSON { staticAsiaOverlays in
        //            mapView.addOverlays(staticAsiaOverlays)
        
        // Add dynamic overlays from the first GeoJSON
        self.parseDynamicGeoJSON { dynamicOverlays in
            mapView.addOverlays(dynamicOverlays)
            
            // Add static overlays from the second GeoJSON
            //                parseStaticTaiwanGeoJSON { staticTaiwanOverlays in
            //                    mapView.addOverlays(staticTaiwanOverlays)
            
            // Add epicenter annotation and circular overlays last
            self.addEpicenterAnnotationAndCircles(to: mapView)
        }
//    }}
    }
    
    private func addEpicenterAnnotationAndCircles(to mapView: MKMapView) {
        let epicenterCoordinate = CLLocationCoordinate2D(latitude: eventManager.latB, longitude: eventManager.lonB)
        
        // Add epicenter annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = epicenterCoordinate
        annotation.title = "Epicenter"
        mapView.addAnnotation(annotation)
        
        if (Date().timeIntervalSince(self.eventManager.originTime) < 120) {
            // Add yellow circle (p wave)
            let yellowCircle = MKCircle(center: epicenterCoordinate, radius: EEWService.getPDistance(e: eventManager))
            yellowCircle.title = "YellowCircle"
            mapView.addOverlay(yellowCircle, level: .aboveLabels)
            
            // Add red circle (s wave)
            let redCircle = MKCircle(center: epicenterCoordinate, radius: EEWService.getSDistance(e: eventManager))
            redCircle.title = "RedCircle"
            mapView.addOverlay(redCircle, level: .aboveLabels)
        }
    }
    
    private func parseDynamicGeoJSON(completion: @escaping ([MKOverlay]) -> Void) {
        DispatchQueue.global().async {
            guard let url = Bundle.main.url(forResource: "district_map", withExtension: "json") else {
                logger.warning("Dynamic GeoJSON file not found")
                completion([])
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = MKGeoJSONDecoder()
                let geoJson = try decoder.decode(data)
                
                var overlays = [MKOverlay]()
                for case let feature as MKGeoJSONFeature in geoJson {
                    if let propertiesData = feature.properties,
                       let properties = try JSONSerialization.jsonObject(with: propertiesData, options: []) as? [String: Any],
                       let townID = properties["Town_ID"] as? String {
                        for geometry in feature.geometry {
                            if let polygon = geometry as? MKPolygon {
                                polygon.title = "dynamic_" + townID
                                overlays.append(polygon)
                            } else if let multiPolygon = geometry as? MKMultiPolygon {
                                multiPolygon.title = "dynamic_" + townID
                                overlays.append(multiPolygon)
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(overlays)
                }
            } catch {
                logger.error("Error parsing dynamic GeoJSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
//    private func parseStaticTaiwanGeoJSON(completion: @escaping ([MKOverlay]) -> Void) {
//        DispatchQueue.global().async {
//            guard let url = Bundle.main.url(forResource: "county_map", withExtension: "json") else {
//                logger.warning("Static GeoJSON file not found")
//                completion([])
//                return
//            }
//
//            do {
//                let data = try Data(contentsOf: url)
//                logger.debug("GeoJSON Data: \(data)")
//                let decoder = MKGeoJSONDecoder()
//                let geoJson = try decoder.decode(data)
//                logger.debug("GeoJSON Decoded: \(geoJson)")
//
//                var overlays = [MKOverlay]()
//                for case let feature as MKGeoJSONFeature in geoJson {
//                    if let propertiesData = feature.properties,
//                       let properties = try JSONSerialization.jsonObject(with: propertiesData, options: []) as? [String: Any],
//                       let identifier = properties["COUNTY_ID"] as? String {
//                        for geometry in feature.geometry {
//                            if let polygon = geometry as? MKPolygon {
//                                polygon.title = "static_" + identifier
//                                overlays.append(polygon)
//                            } else if let multiPolygon = geometry as? MKMultiPolygon {
//                                multiPolygon.title = "static_" + identifier
//                                overlays.append(multiPolygon)
//                            }
//                        }
//                    }
//                }
//
//                DispatchQueue.main.async {
//                    completion(overlays)
//                }
//            } catch {
//                logger.error("Error parsing static GeoJSON: \(error.localizedDescription)")
//                DispatchQueue.main.async {
//                    completion([])
//                }
//            }
//        }
//    }
//
//    private func parseStaticAsiaGeoJSON(completion: @escaping ([MKOverlay]) -> Void) {
//        DispatchQueue.global().async {
//            guard let url = Bundle.main.url(forResource: "asia_map", withExtension: "json") else {
//                logger.warning("Static GeoJSON file not found")
//                completion([])
//                return
//            }
//
//            do {
//                let data = try Data(contentsOf: url)
//                logger.debug("GeoJSON Data: \(data)")
//                let decoder = MKGeoJSONDecoder()
//                let geoJson = try decoder.decode(data)
//                logger.debug("GeoJSON Decoded: \(geoJson)")
//
//                var overlays = [MKOverlay]()
//                for case let feature as MKGeoJSONFeature in geoJson {
//                    if let propertiesData = feature.properties,
//                       let properties = try JSONSerialization.jsonObject(with: propertiesData, options: []) as? [String: Any],
//                       let identifier = properties["name"] as? String {
//                        for geometry in feature.geometry {
//                            if let polygon = geometry as? MKPolygon {
//                                polygon.title = "static_" + identifier
//                                overlays.append(polygon)
//                            } else if let multiPolygon = geometry as? MKMultiPolygon {
//                                multiPolygon.title = "static_" + identifier
//                                overlays.append(multiPolygon)
//                            }
//                        }
//                    }
//                }
//
//                DispatchQueue.main.async {
//                    completion(overlays)
//                }
//            } catch {
//                logger.error("Error parsing static GeoJSON: \(error.localizedDescription)")
//                DispatchQueue.main.async {
//                    completion([])
//                }
//            }
//        }
//    }
    
    private func addPatchPolygon(to mapView: MKMapView) {
        // Define the coordinates of the polygon
        let coordinates = [
            CLLocationCoordinate2D(latitude: 22.981819, longitude: 120.794018),
            CLLocationCoordinate2D(latitude: 22.746681, longitude: 120.880627),
            CLLocationCoordinate2D(latitude: 22.873563, longitude: 121.209280),
            CLLocationCoordinate2D(latitude: 23.041607, longitude: 121.178348)
        ]
        
        // Create the polygon
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        polygon.title = "dynamic_1001413"
        
        // Add the polygon to the map view
        mapView.addOverlay(polygon, level: .aboveRoads) // You can choose `.aboveRoads` or `.aboveLabels` depending on your needs
    }
    
    // MARK: - Map Coordinator
    class MapCoordinator: NSObject, MKMapViewDelegate {
        @ObservedObject var eventManager: EventDispatcher
        @State var lastEventIdentifier: String?
        var updateTimer: Timer?
        weak var mapView: MKMapView?
        
        init(eventManager: EventDispatcher) {
            self.eventManager = eventManager
            super.init()
        }
        
        func startCircleUpdateTimer() {
            stopCircleUpdateTimer() // Ensure any existing timer is invalidated
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateCircleRadii()
                if let originTime = self?.eventManager.originTime, Date().timeIntervalSince(originTime) > 120 {
                    self?.stopCircleUpdateTimer()
                }
            }
        }
        
        func stopCircleUpdateTimer() {
            updateTimer?.invalidate()
            updateTimer = nil
            endUpdateCircleRadii()
        }
        
        func updateCircleRadii() {
            guard let mapView = self.mapView else { return }

            let yellowRadius = EEWService.getPDistance(e: eventManager)
            let redRadius = EEWService.getSDistance(e: eventManager)

            let epicenterCoordinate = CLLocationCoordinate2D(latitude: eventManager.latB, longitude: eventManager.lonB)

            mapView.removeOverlays(mapView.overlays.filter { $0.title == "YellowCircle" || $0.title == "RedCircle" })

            let yellowCircle = MKCircle(center: epicenterCoordinate, radius: yellowRadius)
            yellowCircle.title = "YellowCircle"
            mapView.addOverlay(yellowCircle, level: .aboveLabels)

            let redCircle = MKCircle(center: epicenterCoordinate, radius: redRadius)
            redCircle.title = "RedCircle"
            mapView.addOverlay(redCircle, level: .aboveLabels)
        }
        
        func endUpdateCircleRadii() {
            guard let mapView = self.mapView else { return }
            mapView.removeOverlays(mapView.overlays.filter { $0.title == "YellowCircle" || $0.title == "RedCircle" })
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                return polygonRenderer(for: polygon)
            } else if let multiPolygon = overlay as? MKMultiPolygon {
                return multiPolygonRenderer(for: multiPolygon)
            } else if let circle = overlay as? MKCircle {
                return circleRenderer(for: circle)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // MARK: - User heading cone

        private var headingAnnotation: UserHeadingAnnotation?
        private weak var headingView: UserHeadingAnnotationView?

        /// Keeps the cone under the dot. MapKit reports the user's position here rather
        /// than through the app's own LocationManager, so the two can never disagree about
        /// where the dot is.
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let coordinate = userLocation.location?.coordinate else { return }
            if let headingAnnotation {
                headingAnnotation.coordinate = coordinate
            } else {
                let annotation = UserHeadingAnnotation(coordinate: coordinate)
                headingAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
        }

        /// Hidden rather than removed when there is no reading: the compass drops out
        /// briefly near interference, and removing the annotation would make the cone
        /// flicker in and out.
        func apply(heading: CLLocationDirection?) {
            guard let heading else {
                headingView?.isHidden = true
                return
            }
            headingView?.isHidden = false
            headingView?.apply(heading: heading)
        }

        func removeHeadingAnnotation(from mapView: MKMapView) {
            guard let headingAnnotation else { return }
            mapView.removeAnnotation(headingAnnotation)
            self.headingAnnotation = nil
            headingView = nil
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let heading = annotation as? UserHeadingAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: UserHeadingAnnotationView.identifier) as? UserHeadingAnnotationView
                    ?? UserHeadingAnnotationView(annotation: heading, reuseIdentifier: UserHeadingAnnotationView.identifier)
                view.annotation = heading
                headingView = view
                return view
            }

            if annotation.title == "Epicenter" {
                let identifier = "Epicenter"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                annotationView?.image = UIImage(named: "EpicenterCross")
                
                return annotationView
            }
            
            return nil
        }
        
        private func polygonRenderer(for polygon: MKPolygon) -> MKPolygonRenderer {
            if polygon.title!.starts(with: "static_") {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.clear
                renderer.strokeColor = UIColor.black
                renderer.lineWidth = 1
                return renderer
            } else {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = fillColor(for: polygon.title ?? "")
                renderer.strokeColor = UIColor.black
                renderer.lineWidth = 0.25
                return renderer
            }
        }
        
        private func multiPolygonRenderer(for multiPolygon: MKMultiPolygon) -> MKMultiPolygonRenderer {
            if multiPolygon.title!.starts(with: "static_") {
                let renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygon)
                renderer.fillColor = UIColor.clear
                renderer.strokeColor = UIColor.black
                renderer.lineWidth = 1
                return renderer
            } else {
                let renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygon)
                renderer.fillColor = fillColor(for: multiPolygon.title ?? "")
                renderer.strokeColor = UIColor.black
                renderer.lineWidth = 0.25
                return renderer
            }
        }
        
        private func circleRenderer(for circle: MKCircle) -> MKCircleRenderer {
            let renderer = MKCircleRenderer(circle: circle)
            if circle.title == "YellowCircle" {
                renderer.fillColor = UIColor.yellow.withAlphaComponent(0.05)
                renderer.strokeColor = .orange
            } else if circle.title == "RedCircle" {
                renderer.fillColor = UIColor.red.withAlphaComponent(0.1)
                renderer.strokeColor = UIColor.red
            }
            renderer.lineWidth = 2
            return renderer
        }
        
        func fillColor(for identifier: String) -> UIColor {
            if identifier.starts(with: "dynamic_") {
                let townID = String(identifier.dropFirst(8))  // Remove "dynamic_" prefix
                if townID.prefix(2) != "09" {  // exclude unsupported areas
                    let sel = Location.selectionFromID(id: Location.polygonIDMapping[townID]!)
                    let loc = Location.cities[sel[0]].district[sel[1]]
                    let intensity = EEWService.pgaToIntensity(pga: EEWService.pga(ML: eventManager.magnitude,
                                                                                  depth: eventManager.depth,
                                                                                  dist: EEWService.dist(latA: loc.lat, lonA: loc.lon,
                                                                                                        latB: eventManager.latB, lonB: eventManager.lonB),
                                                                                  Si: loc.si,
                                                                                  Padj: eventManager.pgaAdj))
                    return UIColor(Color(intensity))
                } else {
                    return UIColor.gray
                }
            } else {
                return UIColor.clear
            }
        }
        
        func mapView(_ mapView: MKMapView, didAdd renderers: [MKOverlayRenderer]) {
            mapView.exchangeSubview(at: mapView.subviews.count - 1, withSubviewAt: mapView.subviews.count - 3)
        }
    }
}
