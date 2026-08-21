//
//  EpicenterName.swift
//  TaiwanEEW
//
//  Turning epicenter coordinates into something readable. Extracted from EEWDetailBlock
//  because the compact card layout needs the same answer, and two copies of the ocean
//  region boundaries would drift.
//

import Foundation
import CoreLocation
import os.log

enum EpicenterName {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                       category: "EpicenterName")

    /// Reverse geocodes, falling back to the sea area when the coordinates are offshore
    /// and the geocoder has no placemark to offer.
    ///
    /// - Note: pinned to zh-Hant for every locale, matching the rest of the alert screen.
    ///   The whole screen needs one localization pass rather than piecemeal keys.
    static func resolve(lat: Double, lon: Double) async -> String {
        let geoCoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lon)

        do {
            let placemarks = try await geoCoder.reverseGeocodeLocation(
                location, preferredLocale: Locale(identifier: "zh-Hant"))
            if let placemark = placemarks.first,
               let locality = placemark.administrativeArea,
               let subLocality = placemark.locality {
                return "\(locality)\(subLocality)"
            }
            return oceanArea(lat: lat, lon: lon)
        } catch {
            logger.error("Geocoding error: \(error.localizedDescription)")
            return oceanArea(lat: lat, lon: lon)
        }
    }

    /// CWA's sea area names, which the geocoder cannot produce because there is no
    /// placemark out there.
    static func oceanArea(lat: Double, lon: Double) -> String {
        if lat >= 24.31343 && lon >= 121.76857 { return "東北部海域" }
        if lat >= 23.43494 && lat <= 24.31343 && lon >= 121 { return "東部海域" }
        if lat >= 22.24595 && lat <= 23.43494 && lon >= 120.79958 { return "東南部海域" }
        if lat >= 24.73429 && lon <= 121.76857 { return "北部海域" }
        if lat >= 23.53352 && lat <= 24.73429 && lon <= 121 { return "中部海域" }
        return "南部海域"
    }
}
