//
//  PinnedEventBlock.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2025/7/19.
//

import SwiftUI
import MapKit

struct PinnedEventBlock: View {
    @Environment(\.colorScheme) var colorScheme
    var e: EqReport
    @StateObject private var viewModel: HistoryDetailsViewModel
    let cornerRad: CGFloat = 20
    
    
    // MARK: - Displayed Info
    var earthquakeNo: Int { e.getEqNumber() }
    var maxIntensity: String { e.getMaxIntensity() ?? "未知" }
    var location: String { e.getLocationDesc() ?? "未知" }
    var depth: Float { Float(e.depth) }
    var magnitude: Float {
        Float(e.mag)
    }
    
    var originTime: Date {e.getDate()}
    var originTimeFormattedStr: String {
        let dateFormatter = DateFormatter()
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let eventYear = Calendar.current.component(.year, from: originTime)
        
        if currentYear == eventYear {
            dateFormatter.dateFormat = "MM/dd HH:mm:ss"
        } else {
            dateFormatter.dateFormat = "yyyy MM/dd HH:mm:ss"
        }
        return dateFormatter.string(from: originTime)
    }
    
    var isRecent: Bool {
        return originTime > Date().addingTimeInterval(-12 * 60 * 60)
    }
    
    init(e: EqReport, viewModel: EarthquakeViewModel) {
        self.e = e
        _viewModel = StateObject(wrappedValue: HistoryDetailsViewModel(initialEarthquake: e, earthquakeViewModel: viewModel))
    }
    
    // MARK: Displayed Info -
    
    var body: some View{
        
        Rectangle()
            .frame(width: UIScreen.screenWidth - UIScreen.baseLine-10, height: 90+200)
            .foregroundColor( Color("Pad") )
            .overlay(
                
                VStack(spacing: 0){
                    CustomMapView(earthquake: $viewModel.detailedEarthquake)
                        .frame(height: 200)
                    
                    HStack(spacing: 0){
                        
                        // MARK: - Left
                        Spacer().frame(width: 28)
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .frame(width: 50, height: 50)
                                .foregroundStyle( Color(maxIntensity) )
                            // MARK: 最大震度
                            Text(maxIntensity)
                                .font(.system(size: 32))
                                .bold()
                                .foregroundStyle( maxIntensity == "7" || maxIntensity == "6+" || maxIntensity == "6-" || maxIntensity == "5+" ? .white : .black)
                        }
                        .frame(width: 50)
                        
                        // MARK: - Middle
                        Spacer().frame(width: 22)
                        
                        VStack (alignment: .leading){
                            Spacer()
                            
                            // MARK: 震央
                            HStack(spacing: 5){
                                if isRecent {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.black, .yellow)
                                }
                                Text(location)
                                    .font(.system(size: 20))
                                    .fontWeight(.bold)
                                    .foregroundColor( colorScheme == .dark ? .white : .black)
                            }
                            Spacer().frame(height: 3)
                            // MARK: 時間
                            Text("\(originTimeFormattedStr)")
                                .font(.system(size: 17))
                                .fontWeight(.regular)
                                .foregroundStyle( Color("DescText") )
                            // MARK: 深度
                            Text( String(format: "深度  %.1f  km", depth) )
                                .font(.system(size: 17))
                                .foregroundStyle( Color("DescText") )
                            
                            Spacer()
                        }
                        .frame(width: 170.0, alignment: .leading)
                        
                        // MARK: - Right
                        Spacer().frame(width: 15)
                        VStack(spacing: 2){
                            
                            // MARK: 規模
                            Text( String(format: "M%.1f", magnitude) )
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor( magnitude >= 7 ? .purple : magnitude >= 6 ? .red : magnitude >= 5 ? .orange : colorScheme == .dark ? .white : .black)
                            
                            // MARK: 編號
                            if (earthquakeNo%1000 != 0) {
                                ZStack {
                                    Capsule()
                                        .frame(width: 52, height: 22)
                                        .foregroundStyle( Color("Highlighter") )
                                    HStack(spacing: 2) {
                                        Image(systemName: "number")
                                            .font(.system(size: 12))
                                        Text(verbatim: "\(earthquakeNo%1000)")
                                            .font(.system(size: 12))
                                    }
                                }
                            }
                        }
                        .frame(width: 50)
                        Spacer()
                        
                    }
                    .frame(height: 90)
                }
                
                
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRad))
        // Clip rectangle into rounded rectangle
        
        // Draw border
            .overlay(RoundedRectangle(cornerRadius: cornerRad)
                .stroke(Color("EqInfoBoarder"), lineWidth: 1))
            .onAppear {
                viewModel.fetchDetailedEarthquake()
            }
        
        
    }
}


// copied from historydetailsView
private struct CustomMapView: UIViewRepresentable {
    typealias UIViewType = MKMapView
    
    let mapView = MKMapView()
    @Binding var earthquake: EqReportDetailed?
    
    func makeUIView(context: Context) -> MKMapView {
        setupRegionForMap(mapView)
        setupMapBoundary(mapView)
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        if #available(iOS 16.0, *) {
            let configuration = MKStandardMapConfiguration()
            configuration.pointOfInterestFilter = .excludingAll
            configuration.showsTraffic = false
            mapView.preferredConfiguration = configuration
        }
        
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        
        // Add annotations for each earthquake station
//        addEpicenterAnnotation()
//        addEarthquakeStationAnnotations()
        
        // Set the delegate
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        
        guard let newEarthquake = earthquake,
              context.coordinator.shouldUpdateMap(newEarthquake) else {
            return
        }
        
        // Remove existing annotations
        uiView.removeAnnotations(uiView.annotations)
        
        // Add annotations if earthquake data is available
        if let earthquake = earthquake {
            addEpicenterAnnotation(to: uiView, earthquake: earthquake)
            addEarthquakeStationAnnotations(to: uiView, earthquake: earthquake)
            
            // Calculate and set the region that fits all annotations
//            if let region = regionThatFitsAllAnnotations(in: uiView) {
//                let adjustedRegion = adjustRegionToTopHalf(region, for: uiView)
//                uiView.setRegion(adjustedRegion, animated: true)
//            }
        }
        
        // Update the coordinator's stored earthquake data
        context.coordinator.lastEarthquake = newEarthquake
    }
    
    private func regionThatFitsAllAnnotations(in mapView: MKMapView) -> MKCoordinateRegion? {
        guard !mapView.annotations.isEmpty else { return nil }

        var minLat = mapView.annotations[0].coordinate.latitude
        var maxLat = minLat
        var minLon = mapView.annotations[0].coordinate.longitude
        var maxLon = minLon

        for annotation in mapView.annotations {
            minLat = min(minLat, annotation.coordinate.latitude)
            maxLat = max(maxLat, annotation.coordinate.latitude)
            minLon = min(minLon, annotation.coordinate.longitude)
            maxLon = max(maxLon, annotation.coordinate.longitude)
        }

        guard let lat = earthquake?.lat, let lon = earthquake?.lon else {
            return nil
        }
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let span = MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)

        return MKCoordinateRegion(center: center, span: span)
    }

    private func adjustRegionToTopHalf(_ region: MKCoordinateRegion, for mapView: MKMapView) -> MKCoordinateRegion {
        let verticalOffset = region.span.latitudeDelta * 0.3 // Adjust this value to move the center point up or down
        let newCenterLatitude = region.center.latitude - verticalOffset
        
        let newCenter = CLLocationCoordinate2D(latitude: newCenterLatitude, longitude: region.center.longitude)
        return MKCoordinateRegion(center: newCenter, span: region.span)
    }
    
    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }
    
    private func setupRegionForMap(_ mapView: MKMapView) {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 23.8, longitude: 121.2),
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
        )
        mapView.setRegion(region, animated: true)
    }
    
    private func setupMapBoundary(_ mapView: MKMapView) {
        let northEast = CLLocationCoordinate2D(latitude: 25.3, longitude: 122.0)
        let southWest = CLLocationCoordinate2D(latitude: 21.9, longitude: 120.0)
        
        let boundingRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (northEast.latitude + southWest.latitude) / 2,
                longitude: (northEast.longitude + southWest.longitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: northEast.latitude - southWest.latitude,
                longitudeDelta: northEast.longitude - southWest.longitude
            )
        )
        
        let boundary = MKMapView.CameraBoundary(coordinateRegion: boundingRegion)
        mapView.cameraBoundary = boundary
        
        let zoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 50000,
                                                  maxCenterCoordinateDistance: 2500000)
        mapView.cameraZoomRange = zoomRange
    }
    
    private func addEpicenterAnnotation(to mapView: MKMapView, earthquake: EqReportDetailed) {
        let epicenterCoordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(earthquake.lat), longitude: CLLocationDegrees(earthquake.lon))
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = epicenterCoordinate
        annotation.title = "Epicenter"
        mapView.addAnnotation(annotation)
    }
    
    private func addEarthquakeStationAnnotations(to mapView: MKMapView, earthquake: EqReportDetailed) {
        // Helper function to calculate distance in km between two lat/lon points using Haversine formula
        func distanceKM(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
            let earthRadius = 6371.0 // Radius of the earth in km
            let dLat = (lat2 - lat1) * Double.pi / 180.0
            let dLon = (lon2 - lon1) * Double.pi / 180.0
            let a = sin(dLat/2) * sin(dLat/2) +
                    cos(lat1 * Double.pi / 180.0) * cos(lat2 * Double.pi / 180.0) *
                    sin(dLon/2) * sin(dLon/2)
            let c = 2 * atan2(sqrt(a), sqrt(1-a))
            return earthRadius * c
        }
        // Store best annotation for each 10km grouping
        var groupedAnnotations: [(intensityOrder: Int, annotation: StationAnnotation)] = []

        for (county, countyData) in earthquake.list {
            for (town, townData) in countyData.town {
                let intensityString = convertIntensity(townData.int)
                let annotation = StationAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: townData.lat, longitude: townData.lon),
                    title: "\(county) \(town)",
                    subtitle: "震度\(intensityString)",
                    intensity: intensityString
                )
                let intensityOrder: Int
                switch intensityString {
                case "7": intensityOrder = 9
                case "6強": intensityOrder = 8
                case "6弱": intensityOrder = 7
                case "5強": intensityOrder = 6
                case "5弱": intensityOrder = 5
                case "4": intensityOrder = 4
                case "3": intensityOrder = 3
                case "2": intensityOrder = 2
                case "1": intensityOrder = 1
                default: intensityOrder = 0
                }

                var found = false
                for i in 0..<groupedAnnotations.count {
                    let other = groupedAnnotations[i].annotation
                    let dist = distanceKM(townData.lat, townData.lon, other.coordinate.latitude, other.coordinate.longitude)
                    if dist < 12.0 {
                        found = true
                        // Only replace if this station is higher intensity
                        if intensityOrder > groupedAnnotations[i].intensityOrder {
                            groupedAnnotations[i] = (intensityOrder, annotation)
                        }
                        break
                    }
                }
                if !found {
                    groupedAnnotations.append((intensityOrder, annotation))
                }
            }
        }
        for value in groupedAnnotations {
            mapView.addAnnotation(value.annotation)
        }
    }

    private func convertIntensity(_ int: Int) -> String {
        switch int {
        case 1, 2, 3, 4:
            return int.formatted()
        case 5:
            return "5弱"
        case 6:
            return "5強"
        case 7:
            return "6弱"
        case 8:
            return "6強"
        case 9:
            return 7.formatted()
        default:
            return "未知"
        }
    }
    
    class MapCoordinator: NSObject, MKMapViewDelegate {
        var lastEarthquake: EqReportDetailed?

        func shouldUpdateMap(_ newEarthquake: EqReportDetailed) -> Bool {
            // Compare the new earthquake data with the last updated data
            guard let lastEarthquake = lastEarthquake else {
                return true // Always update if there's no previous data
            }

            // Compare key properties that would necessitate a map update
            return lastEarthquake.id != newEarthquake.id
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
                annotationView?.zPriority = .max // Set epicenter to the top
                
                return annotationView
            } else if let stationAnnotation = annotation as? StationAnnotation {
                let identifier = "StationAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: stationAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = stationAnnotation
                }
                
                annotationView?.image = UIImage(named: imageNameForIntensity(stationAnnotation.intensity))
                annotationView?.zPriority = zPriorityForIntensity(stationAnnotation.intensity)
                annotationView?.frame.size = CGSize(width: 30, height: 30)
                
                return annotationView
            }
            
            return nil
        }
        
        private func imageNameForIntensity(_ intensity: String) -> String {
            switch intensity {
            case "1": return "r1"
            case "2": return "r2"
            case "3": return "r3"
            case "4": return "r4"
            case "5弱": return "r5L"
            case "5強": return "r5U"
            case "6弱": return "r6L"
            case "6強": return "r6U"
            case "7": return "r7"
            default: return "defaultMarker"
            }
        }
        
        private func zPriorityForIntensity(_ intensity: String) -> MKAnnotationViewZPriority {
            switch intensity {
            case "7": return .max
            case "6強": return MKAnnotationViewZPriority(rawValue: 999)
            case "6弱": return MKAnnotationViewZPriority(rawValue: 998)
            case "5強": return MKAnnotationViewZPriority(rawValue: 997)
            case "5弱": return MKAnnotationViewZPriority(rawValue: 996)
            case "4": return MKAnnotationViewZPriority(rawValue: 995)
            case "3": return MKAnnotationViewZPriority(rawValue: 994)
            case "2": return MKAnnotationViewZPriority(rawValue: 993)
            case "1": return MKAnnotationViewZPriority(rawValue: 992)
            default: return .min
            }
        }
    }
}


#Preview {
    PinnedEventBlock(e: MockData.sampleEqReport, viewModel: EarthquakeViewModel())
}

