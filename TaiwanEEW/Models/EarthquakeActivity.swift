//
//  EarthquakeActivity.swift
//  TaiwanEEW
//
//  One definition of "an earthquake is happening right now", shared by the alert card's
//  status bar and the map. Both drive prominent, attention-grabbing UI, so the two
//  disagreeing — a blinking epicenter beside a card saying all is calm, or the reverse —
//  would be worse than either being slightly wrong on its own.
//

import Foundation

enum EarthquakeActivity {
    /// Alerts stay live for a while past the predicted S-wave arrival: the estimate
    /// carries error, and the shaking outlasts the moment it starts.
    static let gracePeriod: TimeInterval = 30

    /// Firestore has not delivered an event yet, so arrivalTime is still its 1970 default
    /// and every comparison against "now" would otherwise read as long past.
    private static let noEventThreshold = Date(timeIntervalSince1970: 1000)

    /// Whether a real report has arrived at all. Exposed because anything keying off the
    /// arrival time needs the same sentinel — treating the 1970 default as a real arrival
    /// reads as "the wave got here decades ago", which is indistinguishable from a genuine
    /// past event unless you know to check.
    static func hasEvent(arrivalTime: Date) -> Bool {
        arrivalTime > noEventThreshold
    }

    /// - Parameter now: injectable so this is testable without waiting for the clock.
    static func isActive(arrivalTime: Date, now: Date = Date()) -> Bool {
        guard hasEvent(arrivalTime: arrivalTime) else { return false }
        return now.addingTimeInterval(-gracePeriod) < arrivalTime
    }
}
