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
    @ObservedObject var eventManager: EventDispatcher
    /// Points of the map's bottom edge the alert card covers, once it has settled.
    ///
    /// A plain number rather than a CardPosition: two card implementations exist and they
    /// compute their height completely differently, so the map is better off not knowing
    /// which one is running.
    var cardObscuredHeight: CGFloat = 0
    /// Which job the map is doing: first-person while the card is expanded, island
    /// overview while it is collapsed. Passed rather than inferred from
    /// cardObscuredHeight, which is a measurement — keying behaviour off "the card is
    /// currently under N points" would break when the compact layout changed height.
    var isCollapsed: Bool = false
    @StateObject private var headingProvider = HeadingProvider()

    var body: some View {
        CustomMapView(eventManager: eventManager,
                      headingProvider: headingProvider,
                      cardObscuredHeight: cardObscuredHeight,
                      isCollapsed: isCollapsed)
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
    let cardObscuredHeight: CGFloat
    let isCollapsed: Bool
    @AppStorage(AwayFramingPreference.storageKey) private var awayFraming = AwayFramingPreference.taiwan
    @AppStorage(CollapsedFramingPreference.storageKey) private var collapsedFraming = CollapsedFramingPreference.taiwanOnly
    /// Draws the framing geometry over the map. Debug and TestFlight only — the toggle
    /// lives in Settings' diagnostics section and is not shown to App Store users.
    @AppStorage("showMapFramingDebug") private var showFramingDebug = false
    @State private var userTrackingMode: MKUserTrackingMode = .none
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CustomMapView")

    /// Only ask MapKit for the user's dot once permission is already granted. Setting
    /// showsUserLocation while the status is still .notDetermined can make MapKit raise
    /// the location prompt itself, which would appear unannounced on the alert screen
    /// rather than where the app actually explains why it wants location.
    private var canShowUserLocation: Bool {
        LocationPermissionStatus(status: locationManager.authorizationStatus).canFetchLocation
    }

    // MARK: - Make Map View
    func makeUIView(context: Context) -> MKMapView {
        // Built here, not stored on the struct. SwiftUI recreates this value whenever
        // anything it observes changes — and headingProvider publishes every couple of
        // degrees of compass movement, so turning the phone did it several times a second.
        // As a stored property that allocated a whole new MKMapView each time, spinning up
        // a map engine and discarding it, while the one SwiftUI actually kept was the
        // single instance makeUIView returned on the first pass.
        let mapView = MKMapView()
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
        // Redrawn every pass so it stays correct after a rotation or relayout.
        drawTargetArea(on: uiView, insets: Self.mapInsets(for: uiView, obscuredByCard: cardObscuredHeight))

        // Dragging the card changes how much map is left, so both the area being framed
        // into and what fits inside it have to be worked out again. Keyed on the settled
        // position rather than the drag, so this runs once when the card lands.
        if context.coordinator.lastCardObscuredHeight != cardObscuredHeight
            || context.coordinator.lastIsCollapsed != isCollapsed {
            context.coordinator.lastCardObscuredHeight = cardObscuredHeight
            context.coordinator.lastIsCollapsed = isCollapsed
            setupRegionForMap(uiView)
        }

        // The geographic markers are otherwise only drawn while framing, which happens on
        // launch and on a new report — so without this the toggle appeared to do nothing
        // until the next earthquake.
        if context.coordinator.lastFramingDebugEnabled != showFramingDebug {
            context.coordinator.lastFramingDebugEnabled = showFramingDebug
            drawFramingDebug(on: uiView, fitted: preferredMapRect())
        }

        // Reframe the moment the first fix lands. Without this the map keeps whatever it
        // opened with — the epicenter alone — until the next earthquake arrives.
        if !context.coordinator.hasFramedWithUserLocation, locationManager.currentLocation != nil {
            context.coordinator.hasFramedWithUserLocation = true
            setupRegionForMap(uiView)
        }

        let renderKey = Self.renderKey(for: eventManager.event.last)
        if context.coordinator.lastRenderKey != renderKey {
            if (Date().timeIntervalSince(self.eventManager.originTime) < 120) {
                context.coordinator.startCircleUpdateTimer()
            } else {
                context.coordinator.stopCircleUpdateTimer()
            }
            logger.debug("Event identifier changed. Updating dynamic overlays...")
            
            // Update the colors of existing overlays
            context.coordinator.refreshDistrictColours(on: uiView)
            
            // Remove and re-add epicenter annotation and circles
            uiView.removeAnnotations(uiView.annotations.filter { $0.title == "Epicenter" })
            context.coordinator.removeWaveFronts(from: uiView)
            addEpicenterAnnotationAndCircles(to: uiView, coordinator: context.coordinator)
            
            // Remember what was just drawn
            context.coordinator.lastRenderKey = renderKey
            
            if eventManager.latB != 0 {
                setupRegionForMap(uiView)
            }
        }
    }
    
    /// Every value the map's drawing reads, combined into one fingerprint.
    ///
    /// Not the identifier alone: that is the CWA event id, identical across every revision
    /// of one earthquake, so keying on it drew the first message and ignored the rest.
    /// Not identifier and msgNo alone either — a report can be corrected without the
    /// number moving, and then the epicenter, the circles and every district colour would
    /// go on describing the superseded figures. Keying on the inputs themselves means the
    /// map redraws exactly when the picture would differ, and stays still otherwise, which
    /// is what keeps compass updates from rebuilding it.
    private static func renderKey(for report: EEWReport?) -> String? {
        guard let report else { return nil }
        return [
            report.identifier,
            String(report.msgNo),
            String(report.magnitudeValue),
            String(report.depth),
            String(report.epicenterLat),
            String(report.epicenterLon),
            String(report.pgaAdj),
            String(report.originTime.timeIntervalSince1970)
        ].joined(separator: "#")
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator(eventManager: eventManager)
    }
    
    // MARK: - Framing

    /// The island, corner to corner, for when there is nothing better to frame.
    ///
    /// Given as explicit corners rather than a centre and a radius so the box is the shape
    /// of Taiwan rather than a square around it — a square wastes the difference on sea,
    /// and it is the longer side that decides the zoom.
    private static let taiwanNorthEast = CLLocationCoordinate2D(latitude: 25.4, longitude: 122.2)
    private static let taiwanSouthWest = CLLocationCoordinate2D(latitude: 21.893754, longitude: 119.377507)

    /// Fraction trimmed off each side of the island box before it is framed.
    ///
    /// The corners above bound the island with some sea around it; this pulls the view in
    /// onto land. Set to 0 to frame exactly the corners as given.
    private static let taiwanFramingInset = 0.20

    private static func taiwanRect(inset: Double = taiwanFramingInset) -> MKMapRect {
        let northEast = MKMapPoint(taiwanNorthEast)
        let southWest = MKMapPoint(taiwanSouthWest)
        // y grows southward in map points, so the corners cannot be assumed to be in order.
        let full = MKMapRect(x: min(northEast.x, southWest.x),
                             y: min(northEast.y, southWest.y),
                             width: abs(northEast.x - southWest.x),
                             height: abs(northEast.y - southWest.y))
        guard inset != 0 else { return full }
        return full.insetBy(dx: full.width * inset, dy: full.height * inset)
    }
    /// One point and no second reference — show its surroundings.
    private static let soloMetres: CLLocationDistance = 200_000
    /// How far from the nearest district still counts as being in Taiwan. Compared against
    /// the closest district rather than a latitude and longitude box, which would have to
    /// be drawn so wide to include 金門, 馬祖 and 澎湖 that it would swallow a good part of
    /// the mainland along with them.
    private static let taiwanProximityMetres: CLLocationDistance = 100_000
    /// Floor on the fitted view. A quake on top of you should still show the region it
    /// happened in, not the street you are standing on.
    private static let minimumMetres: CLLocationDistance = 50_000
    /// Side clearance. Both markers sit on the box's corners by construction, so without
    /// this they land on the screen edge, half cut off. Generous because horizontal room
    /// is cheap — nothing else is competing for it.
    private static let horizontalMargin: CGFloat = 8
    /// Top and bottom clearance, beyond the safe area and the card. Deliberately small:
    /// vertical room is the scarce kind. The card already takes 457pt of an 852pt screen,
    /// so every point added here costs about 1% of the map that is actually visible — at
    /// 88 a side the usable band fell to a quarter of the view and the map showed nearly
    /// four times the area that mattered.
    private static let verticalMargin: CGFloat = 8
    /// Two things float over the top of the map, and they are cleared in different
    /// directions because they are shaped differently.
    ///
    /// The intensity legend is narrow and tall — about 36pt wide but reaching 88pt below
    /// the status bar. Clearing it sideways costs 36pt of width; clearing it downwards
    /// would cost 88pt of height, and height is the scarce axis here.
    ///
    /// The connection pill is the reverse: it ends 20pt below the status bar but runs
    /// about 150pt across, so it is far cheaper to clear downwards.
    private static let legendWidth: CGFloat = 36
    private static let statusPillHeight: CGFloat = 20

    private static let targetAreaTag = 77_301

    private func setupRegionForMap(_ mapView: MKMapView) {
        let rect = preferredMapRect()
        let insets = Self.mapInsets(for: mapView, obscuredByCard: cardObscuredHeight)
        mapView.setVisibleMapRect(rect, edgePadding: insets, animated: true)
        drawTargetArea(on: mapView, insets: insets)
        drawFramingDebug(on: mapView, fitted: rect)
        logFraming(mapView, requested: rect, insets: insets)
    }

    /// Outlines the area the map is actually being fitted into — the view minus the status
    /// bar, the alert card and the margins.
    ///
    /// Drawn in screen space rather than on the map, because that is what it describes: it
    /// does not move when the map pans. If the geographic box from drawFramingDebug does
    /// not sit inside this one, the placement is wrong. If it does sit inside and still
    /// looks off, this rectangle is wrong — which is the part worth checking first, since
    /// the card height is read from CardPosition and may not match what is on screen.
    func drawTargetArea(on mapView: MKMapView, insets: UIEdgeInsets) {
        mapView.viewWithTag(Self.targetAreaTag)?.removeFromSuperview()
        guard showFramingDebug, LocationManager.isDiagnosticsAvailable else { return }

        let box = UIView(frame: mapView.bounds.inset(by: insets))
        box.tag = Self.targetAreaTag
        box.isUserInteractionEnabled = false
        box.backgroundColor = .clear
        box.layer.borderColor = UIColor.systemGreen.cgColor
        box.layer.borderWidth = 2
        mapView.addSubview(box)
    }

    /// Reports what was asked for against what MapKit settled on.
    ///
    /// The fitted box keeps coming out smaller than the space reserved for it, and the two
    /// candidate causes need different fixes. If MapKit rounds the zoom to a coarser step
    /// it wastes up to half the scale, and no amount of inset tuning corrects that. If the
    /// card reserve is simply too large, that is one wrong number. The ratio separates
    /// them: near 1 means the fit is honest and the insets are just too big; near 2 means
    /// the zoom was rounded.
    private func logFraming(_ mapView: MKMapView, requested: MKMapRect, insets: UIEdgeInsets) {
        guard showFramingDebug, LocationManager.isDiagnosticsAvailable else { return }

        let metresPerPoint = 1 / MKMapPointsPerMeterAtLatitude(mapView.centerCoordinate.latitude)
        let requestedKm = requested.height * metresPerPoint / 1000
        let viewHeight = mapView.bounds.height
        let usableBand = viewHeight - insets.top - insets.bottom
        let safeTop = mapView.safeAreaInsets.top

        // Read back after the animation, so this is what ended up on screen rather than
        // what was asked for.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let visibleKm = mapView.visibleMapRect.height * metresPerPoint / 1000
            let bandCoversKm = visibleKm * (usableBand / max(viewHeight, 1))
            let ratio = bandCoversKm / max(requestedKm, 0.001)
            logger.info("framing — view \(viewHeight)pt safeTop \(safeTop)pt insets \(insets.top)/\(insets.bottom) band \(usableBand)pt | requested \(requestedKm)km, band now covers \(bandCoversKm)km, ratio \(ratio)")
        }
    }

    /// Shows what the framing decided: the box being fitted, the line between the two
    /// points, and the geometric midpoint.
    ///
    /// The midpoint marker will not sit in the middle of the screen, and that is the
    /// useful part — the gap between it and the visual centre is the edge padding and the
    /// alert card at work. When the framing looks wrong, this separates a box computed
    /// wrongly from a box merely placed differently than expected.
    private func drawFramingDebug(on mapView: MKMapView, fitted rect: MKMapRect) {
        mapView.removeOverlays(mapView.overlays.filter { overlay in
            guard let title = overlay.title ?? nil else { return false }
            return title.hasPrefix("debug_")
        })
        guard showFramingDebug, LocationManager.isDiagnosticsAvailable else { return }

        let corners = [
            MKMapPoint(x: rect.minX, y: rect.minY).coordinate,
            MKMapPoint(x: rect.maxX, y: rect.minY).coordinate,
            MKMapPoint(x: rect.maxX, y: rect.maxY).coordinate,
            MKMapPoint(x: rect.minX, y: rect.maxY).coordinate
        ]
        let box = MKPolygon(coordinates: corners, count: corners.count)
        box.title = "debug_frame"
        mapView.addOverlay(box, level: .aboveLabels)

        guard eventManager.latB != 0,
              let user = locationManager.currentLocation?.coordinate else { return }
        let epicenter = CLLocationCoordinate2D(latitude: eventManager.latB, longitude: eventManager.lonB)

        var ends = [user, epicenter]
        let line = MKPolyline(coordinates: &ends, count: ends.count)
        line.title = "debug_line"
        mapView.addOverlay(line, level: .aboveLabels)

        let midpoint = CLLocationCoordinate2D(latitude: (user.latitude + epicenter.latitude) / 2,
                                              longitude: (user.longitude + epicenter.longitude) / 2)
        // Fixed metres, so it stays a dot rather than growing with the zoom.
        let marker = MKCircle(center: midpoint, radius: 2_000)
        marker.title = "debug_mid"
        mapView.addOverlay(marker, level: .aboveLabels)
    }

    /// The alert card covers the bottom of the screen, so the map is fitted into what is
    /// left above it rather than into the whole view — otherwise the thing being centred
    /// ends up behind the card.
    ///
    /// How much the card covers is passed in already measured, rather than reconstructed
    /// here from a position. That distinction matters: the old card's offset is computed
    /// from the full screen height but applied in a coordinate space starting below the
    /// status bar, so deriving its top edge needed a safe-area correction that was found
    /// by measuring on device — its raw value said 395pt while it really sat at 456pt, and
    /// reserving the difference cost 78pt of map nothing was covering. Each card now works
    /// out its own coverage, so that class of bug lives with the card that causes it.
    ///
    /// iPad lays the card out beside the map instead of over it, so nothing is covered.
    private static func mapInsets(for mapView: MKMapView, obscuredByCard: CGFloat) -> UIEdgeInsets {
        let safeTop = mapView.safeAreaInsets.top
        let obscured = Device.deviceType == .iphone
            ? min(max(obscuredByCard, 0), mapView.bounds.height)
            : 0

        return UIEdgeInsets(top: safeTop + statusPillHeight + verticalMargin,
                            left: legendWidth + horizontalMargin,
                            bottom: obscured + verticalMargin,
                            right: horizontalMargin)
    }

    /// Enough room around an offshore epicenter that its marker and wave circles are not
    /// clipped by the edge of the fitted box.
    private static let epicenterMarginMetres: CLLocationDistance = 25_000

    /// What to show. See MapFraming for why the two card positions want different things.
    private func preferredMapRect() -> MKMapRect {
        let epicenter = eventManager.latB == 0
            ? nil
            : CLLocationCoordinate2D(latitude: eventManager.latB, longitude: eventManager.lonB)

        guard !isCollapsed else {
            return collapsedRect(epicenter: epicenter)
        }
        return expandedRect(epicenter: epicenter)
    }

    /// Island first, user position never considered. Collapsing the card is a request to
    /// see the map, so it is untrimmed — the room the card gave back is the point.
    private func collapsedRect(epicenter: CLLocationCoordinate2D?) -> MKMapRect {
        let island = Self.taiwanRect(inset: 0)
        guard collapsedFraming == .taiwanAndEpicenter, let epicenter else { return island }
        return island.union(mapRect(around: epicenter, metres: Self.epicenterMarginMetres))
    }

    /// First-person: where am I relative to this. Only when the user's position can
    /// actually anchor that — otherwise it is their preference which of the two
    /// non-personal views to show.
    private func expandedRect(epicenter: CLLocationCoordinate2D?) -> MKMapRect {
        if let user = locationManager.currentLocation?.coordinate, isNearTaiwan(user) {
            guard let epicenter else { return Self.taiwanRect() }
            return mapRect(spanning: epicenter, and: user)
        }

        switch awayFraming {
        case .epicenter:
            guard let epicenter else { return Self.taiwanRect() }
            return mapRect(around: epicenter, metres: Self.soloMetres)
        case .taiwan:
            return Self.taiwanRect()
        }
    }

    private func isNearTaiwan(_ coordinate: CLLocationCoordinate2D) -> Bool {
        locationManager.findClosestDistrict(to: coordinate).distance <= Self.taiwanProximityMetres
    }

    /// Exactly the box the line between the two points needs, widened to the minimum if
    /// they are close together.
    ///
    /// Done in map points rather than degrees because a degree of longitude is shorter the
    /// further north you are, so a degree-based box would be the wrong shape.
    private func mapRect(spanning a: CLLocationCoordinate2D,
                         and b: CLLocationCoordinate2D) -> MKMapRect {
        let pointA = MKMapPoint(a)
        let pointB = MKMapPoint(b)
        var rect = MKMapRect(x: min(pointA.x, pointB.x),
                             y: min(pointA.y, pointB.y),
                             width: abs(pointA.x - pointB.x),
                             height: abs(pointA.y - pointB.y))

        let midLatitude = (a.latitude + b.latitude) / 2
        let minimum = Self.minimumMetres * MKMapPointsPerMeterAtLatitude(midLatitude)
        if rect.width < minimum {
            rect = rect.insetBy(dx: -(minimum - rect.width) / 2, dy: 0)
        }
        if rect.height < minimum {
            rect = rect.insetBy(dx: 0, dy: -(minimum - rect.height) / 2)
        }
        return rect
    }

    private func mapRect(around centre: CLLocationCoordinate2D,
                         metres: CLLocationDistance) -> MKMapRect {
        let size = metres * MKMapPointsPerMeterAtLatitude(centre.latitude)
        let origin = MKMapPoint(centre)
        return MKMapRect(x: origin.x - size / 2,
                         y: origin.y - size / 2,
                         width: size,
                         height: size)
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
            // Below labels so city and place names remain readable over the intensity
            // polygons. Wave outlines and debug geometry still draw above labels.
            mapView.addOverlays(dynamicOverlays, level: .aboveRoads)
            
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
        // Plain properties. These carried @ObservedObject and @State, which are storage for
        // SwiftUI View structs and have nothing to persist into on a class SwiftUI does not
        // manage. @State in particular silently dropped every write, so lastMessageKey
        // stayed nil and the "event identifier changed" branch in updateUIView ran on every
        // single call — several times a second while the compass moved — rebuilding the
        // wave fronts, re-adding the epicenter and re-animating setRegion each time.
        let eventManager: EventDispatcher
        /// Fingerprint of the last report drawn. See CustomMapView.renderKey.
        var lastRenderKey: String?
        /// The map is framed in makeUIView, which usually runs before the first location
        /// fix — so it opens on the epicenter alone. This lets it reframe once, when the
        /// fix arrives, without reframing on every subsequent location update and fighting
        /// the user's panning.
        var hasFramedWithUserLocation = false
        /// Last state of the debug toggle, so flipping it redraws immediately.
        var lastFramingDebugEnabled: Bool?
        /// How much the card covered the last time the map was framed, so dragging it
        /// reframes into the space that just opened up or closed.
        var lastCardObscuredHeight: CGFloat?
        /// Which mode the last framing was for.
        var lastIsCollapsed: Bool?
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

            guard let fill = fillOverlay else { return }
            fill.pRadius = yellowRadius
            fill.sRadius = redRadius

            // Outlines every tick: repainting two shape layers is a composite, not a redraw.
            redrawWaveOutlines(on: mapView)

            // The fill only when its edge has actually moved on screen, because this one
            // does go through the tile renderer.
            if fill.hasMovedEnoughToRedraw() {
                fill.markDrawn()
                mapView.renderer(for: fill)?.setNeedsDisplay(fill.invalidationRect)
            }
        }
        
        func endUpdateCircleRadii() {
            guard let mapView = self.mapView else { return }
            removeWaveFronts(from: mapView)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is WaveFillOverlay {
                return WaveFillRenderer(overlay: overlay)
            } else if let line = overlay as? MKPolyline {
                return Self.debugLineRenderer(for: line)
            } else if let circle = overlay as? MKCircle {
                return Self.debugMidpointRenderer(for: circle)
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

        private var fillOverlay: WaveFillOverlay?
        private weak var outlineView: WaveFrontLayerView?

        /// Builds the drawing for a new epicenter: one overlay for the fills, beneath the
        /// districts, and a shape-layer view over the map for the outlines.
        func rebuildWaveFronts(on mapView: MKMapView, epicenter: CLLocationCoordinate2D) {
            removeWaveFronts(from: mapView)

            let fill = WaveFillOverlay(center: epicenter)
            fillOverlay = fill
            mapView.addOverlay(fill, level: .aboveRoads)

            let outlines = WaveFrontLayerView(frame: mapView.bounds)
            outlines.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            mapView.addSubview(outlines)
            outlineView = outlines
            lowerOutlinesBelowAnnotations(on: mapView)
        }

        /// Moves the outline view into the container MapKit keeps its annotation views in,
        /// underneath them all.
        ///
        /// Reparenting into that container rather than reordering against the map's own
        /// subviews: annotation views are nested inside the map's content view, so walking
        /// up to a sibling of the map lands on the content view itself, and inserting below
        /// that buries the fronts behind the opaque tile layer — they disappear rather than
        /// move. The annotation container sits above the tiles by construction, which is
        /// what makes it a safe home.
        ///
        /// Idempotent, so it is safe to call whenever annotation views appear.
        func lowerOutlinesBelowAnnotations(on mapView: MKMapView) {
            guard let outlines = outlineView else { return }
            guard let container = mapView.annotations
                .compactMap({ mapView.view(for: $0) })
                .first?.superview else { return }

            // Already where it belongs.
            guard !(outlines.superview === container && container.subviews.first === outlines) else { return }

            outlines.frame = container.bounds
            outlines.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.insertSubview(outlines, at: 0)
        }

        func removeWaveFronts(from mapView: MKMapView) {
            if let fillOverlay {
                mapView.removeOverlay(fillOverlay)
                self.fillOverlay = nil
            }
            outlineView?.removeFromSuperview()
            outlineView = nil
        }

        /// Redraws the outlines from the current radii. Cheap enough for every tick and
        /// every frame of a pan or zoom, because it only rewrites two paths.
        func redrawWaveOutlines(on mapView: MKMapView) {
            guard let outlines = outlineView, let fill = fillOverlay else { return }
            guard fill.pRadius > 0 || fill.sRadius > 0 else {
                outlines.clear()
                return
            }

            let centre = mapView.convert(fill.coordinate, toPointTo: outlines)
            outlines.update(centre: centre,
                            pRadius: screenRadius(for: fill.pRadius, at: fill.coordinate, on: mapView, in: outlines),
                            sRadius: screenRadius(for: fill.sRadius, at: fill.coordinate, on: mapView, in: outlines))
        }

        /// Metres to points on screen, measured from two projected coordinates rather than
        /// derived, so it stays right at any zoom without reimplementing the projection.
        private func screenRadius(for metres: CLLocationDistance,
                                  at centre: CLLocationCoordinate2D,
                                  on mapView: MKMapView,
                                  in view: UIView) -> CGFloat {
            guard metres > 0 else { return 0 }
            let origin = MKMapPoint(centre)
            let offset = metres * MKMapPointsPerMeterAtLatitude(centre.latitude)
            let edge = MKMapPoint(x: origin.x + offset, y: origin.y).coordinate
            let centrePoint = mapView.convert(centre, toPointTo: view)
            let edgePoint = mapView.convert(edge, toPointTo: view)
            return hypot(edgePoint.x - centrePoint.x, edgePoint.y - centrePoint.y)
        }

        /// The outlines live in screen space, so panning or zooming leaves them behind
        /// until they are recomputed.
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            redrawWaveOutlines(on: mapView)
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
            // The annotation container may not have existed when the outline view was
            // created, and MapKit rebuilds these views as the map moves, so re-seat it.
            lowerOutlinesBelowAnnotations(on: mapView)
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
            if polygon.title?.hasPrefix("debug_") == true {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = .clear
                renderer.strokeColor = .systemPurple
                renderer.lineWidth = 2
                renderer.lineDashPattern = [6, 4]
                return renderer
            } else if polygon.title!.starts(with: "static_") {
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
        
        /// Repaints every district from the current report.
        ///
        /// No memoisation. A previous version remembered the last colour applied and
        /// skipped unchanged districts, which was cheaper but wrong: MapKit builds
        /// renderers lazily, so at launch there is often nothing to paint yet, and any
        /// bookkeeping done before that point marks work as finished that never happened.
        /// Repainting all of them is the behaviour that has always worked. If this needs
        /// optimising later, the state has to live where the renderer does — not beside it.
        func refreshDistrictColours(on mapView: MKMapView) {
            for overlay in mapView.overlays {
                guard let title = overlay.title ?? nil,
                      title.hasPrefix("dynamic_"),
                      let renderer = mapView.renderer(for: overlay) as? MKOverlayPathRenderer
                else { continue }
                renderer.fillColor = fillColor(for: title)
            }
        }

        /// The intensity a district is predicted to feel, as the string the colour assets
        /// are named after. nil for overlays that are not intensity polygons.
        private func intensityKey(for identifier: String) -> String? {
            guard identifier.starts(with: "dynamic_") else { return nil }
            let townID = String(identifier.dropFirst(8))  // Remove "dynamic_" prefix
            guard townID.prefix(2) != "09" else { return Self.unsupportedArea }
            // Was a force unwrap. A district present in the geojson but missing from the
            // mapping would have trapped here — on the alert screen, mid-earthquake.
            guard let mappedID = Location.polygonIDMapping[townID] else { return Self.unsupportedArea }

            let sel = Location.selectionFromID(id: mappedID)
            let loc = Location.cities[sel[0]].district[sel[1]]
            return EEWService.pgaToIntensity(pga: EEWService.pga(ML: eventManager.magnitude,
                                                                 depth: eventManager.depth,
                                                                 dist: EEWService.dist(latA: loc.lat, lonA: loc.lon,
                                                                                       latB: eventManager.latB, lonB: eventManager.lonB),
                                                                 Si: loc.si,
                                                                 Padj: eventManager.pgaAdj))
        }

        private static let unsupportedArea = "unsupported"

        private func colour(forIntensity intensity: String) -> UIColor {
            intensity == Self.unsupportedArea ? .gray : UIColor(Color(intensity))
        }

        /// The line whose length the framing is fitted to.
        private static func debugLineRenderer(for line: MKPolyline) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(polyline: line)
            renderer.strokeColor = .systemPurple
            renderer.lineWidth = 2
            renderer.lineDashPattern = [2, 6]
            return renderer
        }

        /// The geometric midpoint. Deliberately not where the screen centres — the offset
        /// between the two is the padding and the alert card.
        private static func debugMidpointRenderer(for circle: MKCircle) -> MKOverlayRenderer {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemPurple.withAlphaComponent(0.9)
            renderer.strokeColor = .white
            renderer.lineWidth = 1
            return renderer
        }

        func fillColor(for identifier: String) -> UIColor {
            guard let intensity = intensityKey(for: identifier) else { return .clear }
            return colour(forIntensity: intensity)
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
            // A newly added overlay is not always composited until something forces a
            // redraw. The subview swap below used to run on every batch and did that as a
            // side effect; once it was limited to running once, the districts — which
            // arrive in a later batch, since the geojson parse is asynchronous — stayed
            // blank at launch until the map was panned. Asking for the invalidation
            // directly does not depend on a side effect of unrelated code.
            renderers.forEach { $0.setNeedsDisplay() }

            guard !hasReorderedSubviews else { return }
            guard mapView.subviews.count >= 3 else { return }
            hasReorderedSubviews = true
            mapView.exchangeSubview(at: mapView.subviews.count - 1, withSubviewAt: mapView.subviews.count - 3)
        }
    }
}
