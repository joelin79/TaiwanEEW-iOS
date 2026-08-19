//
//  WaveFrontOverlay.swift
//  TaiwanEEW
//
//  The expanding P and S wave circles on the alert map.
//
//  MKCircle fixes its radius at construction, so animating one meant removing and re-adding
//  the overlay on every frame. At ten frames a second across four circles that fired the
//  map's delegate callbacks forty times a second, made overlay ordering depend on insertion
//  order that was being rewritten continuously, and threw away every renderer just to draw
//  a slightly larger ring. This overlay keeps its identity and only redraws.
//
//  Each front is still drawn as two overlays: the fill belongs under the district polygons
//  so it never tints the intensity colours, the outline over them so the front stays
//  traceable across whatever it crosses.
//

import MapKit
import UIKit

final class WaveFrontOverlay: NSObject, MKOverlay {
    enum Wave {
        case pWave
        case sWave
    }

    enum Part {
        case fill
        case outline
    }

    let coordinate: CLLocationCoordinate2D
    let wave: Wave
    let part: Part

    /// Current front radius in metres. Set on each tick; the renderer redraws in place.
    var radius: CLLocationDistance = 0

    /// Sized once to the largest the front will ever be drawn, because MapKit reads this
    /// when the overlay is added and caches it — a rect that grew with the radius would be
    /// ignored, and the circle would be clipped to wherever it started.
    ///
    /// The radius timer stops 120 seconds after origin time and the P wave is the faster
    /// of the two, so this bounds the largest circle that can be reached before then.
    let boundingMapRect: MKMapRect

    private static let maxDrawnRadius: CLLocationDistance = 1_000_000   // metres

    init(center: CLLocationCoordinate2D, wave: Wave, part: Part) {
        self.coordinate = center
        self.wave = wave
        self.part = part
        self.boundingMapRect = MKCircle(center: center, radius: Self.maxDrawnRadius).boundingMapRect
    }

    /// The area the front currently occupies, for invalidating just that much.
    ///
    /// Redrawing the whole boundingMapRect instead means asking MapKit to re-render a
    /// two-thousand-kilometre square ten times a second; it renders overlays into tiles
    /// asynchronously and falls behind, which shows up as the circles blinking. The front
    /// only ever grows, so the new area covers wherever the old one was drawn.
    var invalidationRect: MKMapRect {
        // Padded because the outline straddles the path rather than sitting inside it, and
        // an unpadded rect can clip the outer half of the stroke.
        let padded = (radius + 2_000) * MKMapPointsPerMeterAtLatitude(coordinate.latitude)
        let centre = MKMapPoint(coordinate)
        return MKMapRect(x: centre.x - padded,
                         y: centre.y - padded,
                         width: padded * 2,
                         height: padded * 2)
    }
}

final class WaveFrontRenderer: MKOverlayRenderer {
    private var front: WaveFrontOverlay? { overlay as? WaveFrontOverlay }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let front, front.radius > 0 else { return }

        // Metres to map points has to be taken at the epicenter's latitude: the projection
        // stretches with distance from the equator, so a fixed conversion would draw the
        // front too small in the north of the island and too large in the south.
        let centre = MKMapPoint(front.coordinate)
        let radiusInPoints = front.radius * MKMapPointsPerMeterAtLatitude(front.coordinate.latitude)
        let circleRect = MKMapRect(x: centre.x - radiusInPoints,
                                   y: centre.y - radiusInPoints,
                                   width: radiusInPoints * 2,
                                   height: radiusInPoints * 2)
        let drawRect = rect(for: circleRect)

        switch front.part {
        case .fill:
            let colour: UIColor = front.wave == .pWave ? .yellow : .red
            let alpha: CGFloat = front.wave == .pWave ? 0.05 : 0.1
            context.setFillColor(colour.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: drawRect)
        case .outline:
            let colour: UIColor = front.wave == .pWave ? .orange : .red
            context.setStrokeColor(colour.cgColor)
            // Divided by the zoom scale so the line stays two points wide on screen
            // rather than thickening as the map zooms out.
            context.setLineWidth(2 / zoomScale)
            context.strokeEllipse(in: drawRect)
        }
    }
}
