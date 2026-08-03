import SwiftUI
import MapKit
import os.log

//mark

#Preview {
    if #available(iOS 17, *) {
        HistoryDetailsView(initialEarthquake: MockData.sampleEqReport, viewModel: EarthquakeViewModel())
    } else {
        // Fallback on earlier versions
    }
}

@available(iOS 17, *)
struct HistoryDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: HistoryDetailsViewModel
    @State var height: CGFloat = 0
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HistoryDetailsView")
    @State private var sheetPresented: Bool = true
    @StateObject var uiModel = UIModel()
    
    
    init(initialEarthquake: EqReport, viewModel: EarthquakeViewModel) {
        _viewModel = StateObject(wrappedValue: HistoryDetailsViewModel(initialEarthquake: initialEarthquake, earthquakeViewModel: viewModel))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top)) {
                CustomMapView(earthquake: $viewModel.detailedEarthquake)
                    .sheet(isPresented: $sheetPresented, onDismiss: {
                        dismiss()
                    }) {
                        EqDetails(viewModel: viewModel, sheetPresented: $sheetPresented)
                            .presentationDetents([.height(200), .fraction(0.4), .fraction(0.95)], selection: $uiModel.selectedDetent)
                            .presentationBackgroundInteraction(
                                .enabled(upThrough: .fraction(0.4))
                            )
                            .presentationDragIndicator(.hidden)
                            .presentationCornerRadius(21)
                            .interactiveDismissDisabled()
                            .onDisappear {
                                sheetPresented = false
                            }
                    }
            }
            .environmentObject(uiModel)
            .navigationTitle(
                viewModel.earthquakeNo % 1000 != 0 ? "第 \(viewModel.earthquakeNo) 號地震報告" : "小區域地震報告"
            )
            .onAppear {
                viewModel.fetchDetailedEarthquake()
                sheetPresented = true  // Ensure sheet is presented when view appears
            }
            .onDisappear {
                withAnimation{sheetPresented = false}  // Ensure sheet is dismissed when navigating away
            }
        }
        
    }
}

@MainActor
class HistoryDetailsViewModel: ObservableObject {
    @Published var detailedEarthquake: EqReportDetailed?
    @Published var originTime: Date
    @Published var origin: String
    @Published var maxInt: String
    @Published var mag: String
    @Published var depth: String
    @Published var earthquakeNo: Int
    @Published var maxIntVal: Int
    
    private let earthquakeViewModel: EarthquakeViewModel
    private let initialEarthquake: EqReport
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HistoryDetailsViewModel")
    
    init(initialEarthquake: EqReport, earthquakeViewModel: EarthquakeViewModel) {
        self.initialEarthquake = initialEarthquake
        self.earthquakeViewModel = earthquakeViewModel
        
        self.originTime = initialEarthquake.getDate()
        self.origin = initialEarthquake.getLocationDesc() ?? ""
        self.maxInt = initialEarthquake.getMaxIntensity() ?? ""
        self.mag = String(format: "%.1f", initialEarthquake.mag)
        self.depth = String(format: "%.1f", initialEarthquake.depth)
        self.earthquakeNo = initialEarthquake.getEqNumber()
        self.maxIntVal = initialEarthquake.int
    }
    
    var originTimeFormattedStr: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        return dateFormatter.string(from: originTime)
    }
    
    func fetchDetailedEarthquake() {
        Task {
            do {
                let details = try await earthquakeViewModel.fetchEarthquakeDetailed(earthquakeID: initialEarthquake.id)
                DispatchQueue.main.async {
                    self.detailedEarthquake = details
                    // Update other properties if needed
                }
            } catch {
                self.logger.error("Error fetching earthquake details: \(error.localizedDescription)")
            }
        }
    }
}

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
            if let region = regionThatFitsAllAnnotations(in: uiView) {
                let adjustedRegion = adjustRegionToTopHalf(region, for: uiView)
                uiView.setRegion(adjustedRegion, animated: true)
            }
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

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.5,
                                    longitudeDelta: (maxLon - minLon) * 1.5)

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
            center: CLLocationCoordinate2DMake(22.5, 120.96082538424629),
            span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
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
        for (county, countyData) in earthquake.list {
            for (town, townData) in countyData.town {
                let intensityString = convertIntensity(townData.int)
                let annotation = StationAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: townData.lat, longitude: townData.lon),
                    title: "\(county) \(town)",
                    subtitle: "震度\(intensityString)",
                    intensity: intensityString
                )
                mapView.addAnnotation(annotation)
            }
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
                annotationView?.zPriority = .min // Set epicenter to the bottom
                
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

class StationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let intensity: String
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, intensity: String) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.intensity = intensity
    }
}
