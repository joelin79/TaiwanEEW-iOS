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
        //
        // The tint is pinned rather than inherited: the dot picks up the app's accent
        // otherwise, which is a red that both breaks the convention users read at a glance
        // and competes with the intensity colours underneath it.
        mapView.tintColor = .systemBlue
        mapView.showsUserLocation = canShowUserLocation

        // Set the delegate
        mapView.delegate = context.coordinator
        
        // Add overlays in the correct order
        addOverlaysInOrder(to: mapView, coordinator: context.coordinator)
        
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

        context.coordinator.apply(reading: canShowUserLocation ? headingProvider.reading : nil)
        context.coordinator.refreshEpicenterBlink()

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
            context.coordinator.removeWaveFronts(from: uiView)
            addEpicenterAnnotationAndCircles(to: uiView, coordinator: context.coordinator)
            
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
    
    private func addOverlaysInOrder(to mapView: MKMapView, coordinator: MapCoordinator) {
        
        // Add map patch if device is under iOS 18 (experiencing map hole bug)
        if #unavailable(iOS 18) {
            self.addPatchPolygon(to: mapView)
        }
        
        //        parseStaticAsiaGeoJSON { staticAsiaOverlays in
        //            mapView.addOverlays(staticAsiaOverlays)
        
        // Add dynamic overlays from the first GeoJSON
        self.parseDynamicGeoJSON { dynamicOverlays in
            // Stated rather than left to the default: the wave fills are added below this
            // level and the outlines at it, so the layering depends on this being explicit.
            mapView.addOverlays(dynamicOverlays, level: .aboveLabels)
            
            // Add static overlays from the second GeoJSON
            //                parseStaticTaiwanGeoJSON { staticTaiwanOverlays in
            //                    mapView.addOverlays(staticTaiwanOverlays)
            
            // Add epicenter annotation and circular overlays last
            self.addEpicenterAnnotationAndCircles(to: mapView, coordinator: coordinator)
        }
//    }}
    }
    
    private func addEpicenterAnnotationAndCircles(to mapView: MKMapView, coordinator: MapCoordinator) {
        let epicenterCoordinate = CLLocationCoordinate2D(latitude: eventManager.latB, longitude: eventManager.lonB)
        
        // Add epicenter annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = epicenterCoordinate
        annotation.title = "Epicenter"
        mapView.addAnnotation(annotation)
        
        if (Date().timeIntervalSince(self.eventManager.originTime) < 120) {
            coordinator.rebuildWaveFronts(on: mapView, epicenter: epicenterCoordinate)
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

            // The epicenter only moves when a new message arrives, which rebuilds these.
            _ = epicenterCoordinate

            for front in waveFronts {
                front.radius = front.wave == .pWave ? yellowRadius : redRadius
                // Only the area the front now covers, not the whole bounding rect it was
                // given room to grow into.
                mapView.renderer(for: front)?.setNeedsDisplay(front.invalidationRect)
            }
        }
        
        func endUpdateCircleRadii() {
            guard let mapView = self.mapView else { return }
            removeWaveFronts(from: mapView)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is WaveFrontOverlay {
                return WaveFrontRenderer(overlay: overlay)
            } else if let polygon = overlay as? MKPolygon {
                return polygonRenderer(for: polygon)
            } else if let multiPolygon = overlay as? MKMultiPolygon {
                return multiPolygonRenderer(for: multiPolygon)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        deinit {
            // Timer retains its target, so leaving these running would keep the coordinator
            // and the map alive after the view is gone.
            updateTimer?.invalidate()
            blinkTimer?.invalidate()
        }

        // MARK: - Epicenter blink

        // MARK: - Wave fronts

        private(set) var waveFronts: [WaveFrontOverlay] = []

        /// Builds the four overlays for a new epicenter: a fill and an outline for each
        /// wave. They live until the next message or the timer stopping, and only their
        /// radius changes in between.
        func rebuildWaveFronts(on mapView: MKMapView, epicenter: CLLocationCoordinate2D) {
            removeWaveFronts(from: mapView)

            let fronts = [
                WaveFrontOverlay(center: epicenter, wave: .pWave, part: .fill),
                WaveFrontOverlay(center: epicenter, wave: .sWave, part: .fill),
                WaveFrontOverlay(center: epicenter, wave: .pWave, part: .outline),
                WaveFrontOverlay(center: epicenter, wave: .sWave, part: .outline)
            ]
            waveFronts = fronts

            // Fills below the districts so they never tint the intensity colours; outlines
            // above them so each front stays traceable across whatever it is crossing.
            for front in fronts where front.part == .fill {
                mapView.addOverlay(front, level: .aboveRoads)
            }
            for front in fronts where front.part == .outline {
                mapView.addOverlay(front, level: .aboveLabels)
            }
        }

        func removeWaveFronts(from mapView: MKMapView) {
            guard !waveFronts.isEmpty else { return }
            mapView.removeOverlays(waveFronts)
            waveFronts = []
        }

        private var hasReorderedSubviews = false
        private static let blinkKey = "epicenterBlink"
        private weak var epicenterView: MKAnnotationView?
        /// Re-checks whether the quake is still live. Runs only while one is, and stops
        /// itself once the window closes.
        private var blinkTimer: Timer?

        /// Blinks the epicenter for as long as the alert card's status bar considers the
        /// earthquake to be in progress.
        ///
        /// The layer's own animation is the source of truth for whether it is currently
        /// blinking, rather than a separate flag, so the two cannot fall out of step when
        /// the annotation is torn down and rebuilt on each new message.
        func refreshEpicenterBlink() {
            let shouldBlink = EarthquakeActivity.isActive(arrivalTime: eventManager.arrivalTime)

            if let view = epicenterView {
                let isBlinking = view.layer.animation(forKey: Self.blinkKey) != nil
                if shouldBlink && !isBlinking {
                    // 0.5s each way, so one full cycle a second.
                    let blink = CABasicAnimation(keyPath: "opacity")
                    blink.fromValue = 1.0
                    blink.toValue = 0.15
                    blink.duration = 0.5
                    blink.autoreverses = true
                    blink.repeatCount = .infinity
                    view.layer.add(blink, forKey: Self.blinkKey)
                } else if !shouldBlink && isBlinking {
                    view.layer.removeAnimation(forKey: Self.blinkKey)
                    view.layer.opacity = 1
                }
            }

            // Deliberately not sharing the circle timer: that one stops 120s after origin
            // time, and a distant quake's arrival plus grace period can outlast it, which
            // would leave the epicenter blinking after the card had gone quiet.
            if shouldBlink, blinkTimer == nil {
                blinkTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    self?.refreshEpicenterBlink()
                }
            } else if !shouldBlink {
                blinkTimer?.invalidate()
                blinkTimer = nil
            }
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
        func apply(reading: HeadingReading?) {
            guard let reading else {
                headingView?.isHidden = true
                return
            }
            headingView?.isHidden = false
            headingView?.apply(reading)
        }

        /// Keeps MapKit's dot on top of the cone.
        ///
        /// zPriority alone does not decide it, and lifting the dot is unreliable: its view
        /// may not exist yet when this fires, and MapKit rebuilds it as the location
        /// updates, which undoes any lift and is why the cone intermittently ended up on
        /// top. The cone is ours and is always there when it matters, so it gets pushed
        /// down instead — which also puts it behind the epicenter, where it belongs.
        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            if let cone = headingView {
                cone.superview?.sendSubviewToBack(cone)
            }
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

                // The annotation is removed and rebuilt on every message, so the blink has
                // to be reapplied to the new view rather than assumed to have survived.
                epicenterView = annotationView
                refreshEpicenterBlink()

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
        
        /// Undocumented subview reordering inherited from before this was open sourced.
        ///
        /// It runs once now rather than on every batch of renderers. Left unguarded it
        /// swapped the same two views back and forth ten times a second, because
        /// updateCircleRadii re-adds every wave circle on each tick — which is what made
        /// the wave outlines flicker above and below the districts. Swapping an even number
        /// of times returns the order to where it started, so the flicker was the swap
        /// itself, not a race.
        func mapView(_ mapView: MKMapView, didAdd renderers: [MKOverlayRenderer]) {
            guard !hasReorderedSubviews else { return }
            guard mapView.subviews.count >= 3 else { return }
            hasReorderedSubviews = true
            mapView.exchangeSubview(at: mapView.subviews.count - 1, withSubviewAt: mapView.subviews.count - 3)
        }
    }
}
