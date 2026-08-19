//
//  WaveFrontOverlay.swift
//  TaiwanEEW
//
//  The expanding P and S wave circles on the alert map, drawn in two different ways for
//  two different reasons.
//
//  The outlines are Core Animation shape layers sitting over the map. MKOverlayRenderer
//  rasterises into tiles on background threads, and setNeedsDisplay throws the cached tile
//  away and schedules a re-render — so at ten updates a second there is always a region
//  waiting on one, which is what made the circles flicker. Shrinking the invalidated area
//  only narrows the window. A shape layer has no tiles: changing its path is a GPU
//  composite, which is what per-frame animation actually wants.
//
//  The fills stay overlays because they have to be beneath the district polygons, and
//  nothing outside MapKit's own rendering can be. They are far more forgiving — one
//  translucent disc at five to ten percent — and are throttled so they only redraw when
//  the edge has moved far enough on screen to see.
//

import MapKit
import UIKit

// MARK: - Fills (below the districts)

/// Both wave fills in a single overlay.
///
/// One overlay rather than two: separate ones invalidate overlapping rectangles, so the
/// tiles where the circles overlap get re-rendered twice for one frame of movement.
final class WaveFillOverlay: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    var pRadius: CLLocationDistance = 0
    var sRadius: CLLocationDistance = 0

    /// The radii last drawn, so the renderer can be left alone when nothing has visibly
    /// changed.
    private var lastDrawnPRadius: CLLocationDistance = 0

    private static let maxDrawnRadius: CLLocationDistance = 1_000_000   // metres

    init(center: CLLocationCoordinate2D) {
        self.coordinate = center
        self.boundingMapRect = MKCircle(center: center, radius: Self.maxDrawnRadius).boundingMapRect
    }

    /// True when the outer edge has moved enough to be worth a redraw.
    ///
    /// The P front is the faster of the two and bounds the invalidated area, so it decides.
    /// Two kilometres is well under a pixel at the zoom this map opens at, and the fill is
    /// a soft translucent wash — nobody can see it lagging the outline by that much, and it
    /// cuts tile work by roughly the ratio between this and the distance travelled per tick.
    func hasMovedEnoughToRedraw() -> Bool {
        abs(pRadius - lastDrawnPRadius) >= 2_000
    }

    func markDrawn() {
        lastDrawnPRadius = pRadius
    }

    var invalidationRect: MKMapRect {
        let padded = (max(pRadius, sRadius) + 5_000) * MKMapPointsPerMeterAtLatitude(coordinate.latitude)
        let centre = MKMapPoint(coordinate)
        return MKMapRect(x: centre.x - padded, y: centre.y - padded,
                         width: padded * 2, height: padded * 2)
    }
}

final class WaveFillRenderer: MKOverlayRenderer {
    private var fill: WaveFillOverlay? { overlay as? WaveFillOverlay }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let fill else { return }

        // The S disc is drawn over the P disc, so the area both waves have reached reads as
        // the stronger of the two rather than the sum of two washes.
        drawDisc(radius: fill.pRadius, colour: UIColor.yellow.withAlphaComponent(0.05),
                 centre: fill.coordinate, in: context)
        drawDisc(radius: fill.sRadius, colour: UIColor.red.withAlphaComponent(0.10),
                 centre: fill.coordinate, in: context)
    }

    private func drawDisc(radius: CLLocationDistance,
                          colour: UIColor,
                          centre: CLLocationCoordinate2D,
                          in context: CGContext) {
        guard radius > 0 else { return }
        // Metres to map points has to be taken at the epicenter's latitude: the projection
        // stretches with distance from the equator.
        let origin = MKMapPoint(centre)
        let radiusInPoints = radius * MKMapPointsPerMeterAtLatitude(centre.latitude)
        let circleRect = MKMapRect(x: origin.x - radiusInPoints, y: origin.y - radiusInPoints,
                                   width: radiusInPoints * 2, height: radiusInPoints * 2)
        context.setFillColor(colour.cgColor)
        context.fillEllipse(in: rect(for: circleRect))
    }
}

// MARK: - Outlines (above the districts)

/// The two wave outlines, drawn as shape layers over the map.
///
/// Everything here is in screen space, so it has to be recomputed whenever the map moves as
/// well as whenever the fronts grow — see the coordinator's regionDidChange.
final class WaveFrontLayerView: UIView {
    /// Colours chosen to sit in the gaps the intensity ramp leaves in hue space. That ramp
    /// occupies 0-46° (red through orange to yellow), 115° (green), 218-222° (the blues)
    /// and 268° (purple). Teal at 183° and magenta at 319° fall in the two wide gaps, and
    /// are 134° apart from each other so the fronts never read as the same line.
    private static let pColour = UIColor(red: 0.00, green: 0.62, blue: 0.65, alpha: 1)
    private static let sColour = UIColor(red: 0.90, green: 0.00, blue: 0.62, alpha: 1)

    private let pLayer = CAShapeLayer()
    private let sLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        // Purely a drawing surface laid over the map; every touch belongs to the map.
        isUserInteractionEnabled = false

        for (shape, colour) in [(pLayer, Self.pColour), (sLayer, Self.sColour)] {
            shape.fillColor = UIColor.clear.cgColor
            shape.strokeColor = colour.cgColor
            shape.lineWidth = 2
            layer.addSublayer(shape)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clear() {
        setPaths(p: nil, s: nil)
    }

    /// - Parameters are already in this view's coordinate space.
    func update(centre: CGPoint, pRadius: CGFloat, sRadius: CGFloat) {
        setPaths(p: circlePath(centre: centre, radius: pRadius),
                 s: circlePath(centre: centre, radius: sRadius))
    }

    private func circlePath(centre: CGPoint, radius: CGFloat) -> CGPath? {
        guard radius > 0, radius.isFinite else { return nil }
        return UIBezierPath(arcCenter: centre, radius: radius,
                            startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
    }

    private func setPaths(p: CGPath?, s: CGPath?) {
        // Without this each path change animates over the default quarter second, so the
        // drawn circle trails the real front instead of tracking it.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pLayer.path = p
        sLayer.path = s
        CATransaction.commit()
    }
}
