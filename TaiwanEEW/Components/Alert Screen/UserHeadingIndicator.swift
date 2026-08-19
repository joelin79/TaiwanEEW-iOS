//
//  UserHeadingIndicator.swift
//  TaiwanEEW
//
//  The direction cone under the user's blue dot, as in Maps.
//
//  MapKit will draw its own heading indicator, but only in .followWithHeading, which keeps
//  the camera pinned to the user and rotates the map under them. The alert map is framed
//  deliberately — the whole island, or the epicenter once a quake is in — so following is
//  not an option. The cone is therefore drawn as an ordinary annotation sitting beneath
//  MapKit's dot, which leaves the dot itself untouched.
//

import MapKit
import CoreLocation
import Combine
import os.log

// MARK: - Heading source

/// Compass heading for the map.
///
/// Deliberately separate from LocationManager: that one runs in the background to switch
/// districts, whereas the magnetometer only earns its power while the map is actually on
/// screen. Started and stopped with the view.
final class HeadingProvider: NSObject, ObservableObject {
    @Published private(set) var heading: CLLocationDirection?

    private let manager = CLLocationManager()
    private var isRunning = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HeadingProvider")

    override init() {
        super.init()
        manager.delegate = self
        // Degrees of change before an update is delivered. Small enough to feel live,
        // large enough not to redraw on every twitch of the magnetometer.
        manager.headingFilter = 2
    }

    func start() {
        guard !isRunning, CLLocationManager.headingAvailable() else { return }
        isRunning = true
        manager.startUpdatingHeading()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopUpdatingHeading()
        // Cleared so the cone disappears rather than freezing at the last known angle,
        // which would keep pointing somewhere the user is no longer facing.
        heading = nil
    }
}

extension HeadingProvider: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Negative accuracy means the reading is invalid — usually interference, or a
        // device that has not been calibrated yet.
        guard newHeading.headingAccuracy >= 0 else {
            heading = nil
            return
        }
        // True north needs location services to know the local declination; magnetic north
        // is the fallback and is close enough for "which way am I facing".
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
}

// MARK: - Annotation

/// Sits at the same coordinate as the user's dot. `dynamic` so MapKit's KVO observation
/// moves the view when the coordinate is reassigned, rather than needing the annotation to
/// be removed and re-added on every location update.
final class UserHeadingAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

// MARK: - Annotation view

/// A wedge fading outwards from the dot, rotated to the compass heading.
final class UserHeadingAnnotationView: MKAnnotationView {
    static let identifier = "UserHeading"

    /// Width of the square the cone is drawn in; the wedge reaches half of this from the
    /// centre, so the cone is `size / 2` long.
    private static let size: CGFloat = 64
    /// Half-angle of the wedge. 30° gives a 60° spread, close to what Maps draws.
    private static let halfAngle = CGFloat.pi / 6

    private let gradient = CAGradientLayer()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        let size = Self.size
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        // The cone is decoration: taps belong to the map underneath it.
        isUserInteractionEnabled = false
        // Hidden until a heading actually arrives, otherwise the wedge shows pointing due
        // north for the moment between the dot appearing and the first compass reading.
        isHidden = true
        // Below MapKit's own dot, so the dot stays crisp on top of the wedge.
        zPriority = .min

        let centre = CGPoint(x: size / 2, y: size / 2)
        let wedge = UIBezierPath()
        wedge.move(to: centre)
        // -.pi/2 is straight up, which is north on a north-up map.
        wedge.addArc(withCenter: centre,
                     radius: size / 2,
                     startAngle: -.pi / 2 - Self.halfAngle,
                     endAngle: -.pi / 2 + Self.halfAngle,
                     clockwise: true)
        wedge.close()

        let mask = CAShapeLayer()
        mask.path = wedge.cgPath

        gradient.frame = bounds
        gradient.colors = [UIColor.systemBlue.withAlphaComponent(0.5).cgColor,
                           UIColor.systemBlue.withAlphaComponent(0.0).cgColor]
        // Radiates from the dot outwards along the wedge.
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.mask = mask
        layer.addSublayer(gradient)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Points the cone at `heading`, in degrees clockwise from north.
    ///
    /// Assumes a north-up map, which holds because rotation is disabled on this one. If
    /// rotation is ever enabled, this has to become `heading - camera.heading` and update
    /// on region change too.
    func apply(heading: CLLocationDirection) {
        // Heading arrives several times a second; the implicit layer animation would lag
        // behind the device and look like drift rather than rotation.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DMakeRotation(CGFloat(heading) * .pi / 180, 0, 0, 1)
        CATransaction.commit()
    }
}
