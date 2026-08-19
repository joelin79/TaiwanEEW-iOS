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

/// A compass reading together with how far off CoreLocation thinks it might be.
struct HeadingReading: Equatable {
    /// Degrees clockwise from north.
    let direction: CLLocationDirection
    /// Maximum deviation in degrees. Drives how wide the cone is drawn, so an uncertain
    /// reading looks uncertain rather than claiming a precision it does not have.
    let accuracy: CLLocationDirection
}

/// Compass heading for the map.
///
/// Deliberately separate from LocationManager: that one runs in the background to switch
/// districts, whereas the magnetometer only earns its power while the map is actually on
/// screen. Started and stopped with the view.
final class HeadingProvider: NSObject, ObservableObject {
    @Published private(set) var reading: HeadingReading?

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
        reading = nil
    }
}

extension HeadingProvider: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Negative accuracy means the reading is invalid — usually interference, or a
        // device that has not been calibrated yet.
        guard newHeading.headingAccuracy >= 0 else {
            reading = nil
            return
        }
        // True north needs location services to know the local declination; magnetic north
        // is the fallback and is close enough for "which way am I facing".
        let direction = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        reading = HeadingReading(direction: direction, accuracy: newHeading.headingAccuracy)
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

/// A wedge fading outwards from the dot, rotated to the compass heading and widened to
/// match how uncertain that heading is.
final class UserHeadingAnnotationView: MKAnnotationView {
    static let identifier = "UserHeading"

    /// Width of the square the cone is drawn in; the wedge reaches half of this from the
    /// centre, so the cone is `size / 2` long.
    ///
    /// Sized against the dot rather than the map: the map is usually framed on the whole
    /// island, where a cone measured in map distance would be invisible, so it is drawn at
    /// a fixed size on screen and reads as a marker rather than a radius.
    private static let size: CGFloat = 100

    /// Bounds on the half-angle, in degrees. A phone straight out of a pocket reports
    /// tens of degrees of error, so the lower bound keeps a well-calibrated compass from
    /// drawing a sliver, and the upper bound stops a badly disturbed one from fanning out
    /// into a semicircle that obscures the districts underneath.
    private static let minHalfAngle: CGFloat = 12
    private static let maxHalfAngle: CGFloat = 55

    private let gradient = CAGradientLayer()
    private let wedgeMask = CAShapeLayer()
    /// Last drawn half-angle in radians, so the path is only rebuilt when the width
    /// actually changes rather than on every heading update.
    private var currentHalfAngle: CGFloat = .nan

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        frame = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)
        // The cone is decoration: taps belong to the map underneath it.
        isUserInteractionEnabled = false
        // Hidden until a heading actually arrives, otherwise the wedge shows pointing due
        // north for the moment between the dot appearing and the first compass reading.
        isHidden = true
        // Below MapKit's own dot. The coordinator lifts the dot as well, because this
        // alone does not settle the order.
        zPriority = .min

        // Maps' blue, deliberately not the app's accent: "where I am and which way I am
        // facing" is a convention users already read at a glance, and the accent here is a
        // red that would compete with the intensity colours the map exists to show.
        let tint = UIColor.systemBlue
        gradient.frame = bounds
        gradient.colors = [tint.withAlphaComponent(0.5).cgColor,
                           tint.withAlphaComponent(0.0).cgColor]
        // Radiates from the dot outwards along the wedge.
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.mask = wedgeMask
        layer.addSublayer(gradient)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Points the cone along the reading and sizes it to the reading's accuracy.
    ///
    /// Assumes a north-up map, which holds because rotation is disabled on this one. If
    /// rotation is ever enabled, the angle has to become `direction - camera.heading` and
    /// update on region change too.
    func apply(_ reading: HeadingReading) {
        // Heading arrives several times a second; the implicit layer animation would lag
        // behind the device and look like drift rather than rotation.
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let halfAngle = Self.halfAngle(forAccuracy: reading.accuracy)
        // Redraw only on a real change — a degree of jitter is not worth a new path.
        if !currentHalfAngle.isFinite || abs(halfAngle - currentHalfAngle) > .pi / 180 {
            currentHalfAngle = halfAngle
            wedgeMask.path = Self.wedgePath(halfAngle: halfAngle).cgPath
        }

        layer.transform = CATransform3DMakeRotation(CGFloat(reading.direction) * .pi / 180, 0, 0, 1)
        CATransaction.commit()
    }

    /// CoreLocation reports accuracy as a maximum deviation in degrees, which is exactly
    /// the half-angle the cone wants — clamped so it stays readable at both extremes.
    private static func halfAngle(forAccuracy accuracy: CLLocationDirection) -> CGFloat {
        let degrees = min(max(CGFloat(accuracy), minHalfAngle), maxHalfAngle)
        return degrees * .pi / 180
    }

    private static func wedgePath(halfAngle: CGFloat) -> UIBezierPath {
        let centre = CGPoint(x: size / 2, y: size / 2)
        let path = UIBezierPath()
        path.move(to: centre)
        // -.pi/2 is straight up, which is north on a north-up map.
        path.addArc(withCenter: centre,
                    radius: size / 2,
                    startAngle: -.pi / 2 - halfAngle,
                    endAngle: -.pi / 2 + halfAngle,
                    clockwise: true)
        path.close()
        return path
    }
}
