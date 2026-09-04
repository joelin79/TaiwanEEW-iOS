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
    /// How long an alert stays live past the predicted S-wave arrival, by magnitude.
    ///
    /// The arrival time is when shaking *starts*, not when it stops, and a bigger rupture
    /// shakes for longer: the fault takes longer to break, and the surface waves that
    /// follow the S-wave arrive over a longer spread. So the window that says "this is
    /// happening now" has to scale with magnitude, or a M7 reads as over while the ground
    /// is still moving.
    ///
    /// Thresholds are inclusive going up — 6.5 exactly gets 3 minutes, 7.0 exactly gets 5 —
    /// and anything below 6.5 gets the 2-minute floor. Magnitude is not carried on every
    /// path (a report can arrive before it is parsed), so 0 falls into that floor rather
    /// than shortening the window.
    static func gracePeriod(magnitude: Double) -> TimeInterval {
        if magnitude >= 7.0 { return 5 * 60 }
        if magnitude >= 6.5 { return 3 * 60 }
        return 2 * 60
    }

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

    /// - Parameters:
    ///   - magnitude: sets how long the window is. See `gracePeriod(magnitude:)`.
    ///   - now: injectable so this is testable without waiting for the clock.
    static func isActive(arrivalTime: Date, magnitude: Double, now: Date = Date()) -> Bool {
        guard hasEvent(arrivalTime: arrivalTime) else { return false }
        return now.addingTimeInterval(-gracePeriod(magnitude: magnitude)) < arrivalTime
    }

    /// How long past arrival the countdown keeps flashing 已抵達.
    ///
    /// The same window, deliberately. It used to be a separate 15 seconds on the argument
    /// that "how long the alert stays live" and "how long it demands attention" are
    /// different questions — but that produced a card whose countdown had gone quiet while
    /// the status bar above it was still in alert, which reads as the alert being over.
    static func isFlashing(arrivalTime: Date, magnitude: Double, now: Date = Date()) -> Bool {
        isActive(arrivalTime: arrivalTime, magnitude: magnitude, now: now)
    }
}
