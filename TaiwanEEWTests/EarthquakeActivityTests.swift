//
//  EarthquakeActivityTests.swift
//  TaiwanEEWTests
//
//  Covers how long an alert counts as live. The status bar, the countdown's flash and the
//  map's blinking epicenter all read this, so a change here silently changes three pieces
//  of UI at once - and the failure is invisible: the alert simply stops looking urgent
//  while the ground is still moving.
//

import XCTest
@testable import TaiwanEEW

final class EarthquakeActivityTests: XCTestCase {

    private typealias Activity = EarthquakeActivity

    // MARK: - Grace period by magnitude

    func testSmallQuakesGetTwoMinutes() {
        XCTAssertEqual(Activity.gracePeriod(magnitude: 4.6), 120)
        XCTAssertEqual(Activity.gracePeriod(magnitude: 5.9), 120)
        XCTAssertEqual(Activity.gracePeriod(magnitude: 6.4), 120)
    }

    func testStrongQuakesGetThreeMinutes() {
        XCTAssertEqual(Activity.gracePeriod(magnitude: 6.5), 180)
        XCTAssertEqual(Activity.gracePeriod(magnitude: 6.9), 180)
    }

    func testMajorQuakesGetFiveMinutes() {
        XCTAssertEqual(Activity.gracePeriod(magnitude: 7.0), 300)
        XCTAssertEqual(Activity.gracePeriod(magnitude: 8.2), 300)
    }

    /// Both thresholds are inclusive going up. 6.5 and 7.0 are exactly the magnitudes CWA
    /// reports, so which side of the boundary they fall on is not academic.
    func testThresholdsAreInclusive() {
        XCTAssertEqual(Activity.gracePeriod(magnitude: 6.5), 180, "6.5 belongs to the 3-minute band")
        XCTAssertEqual(Activity.gracePeriod(magnitude: 7.0), 300, "7.0 belongs to the 5-minute band")
    }

    /// Magnitude is not on every path - a report can be rendered before it is parsed - so
    /// the absent value has to land somewhere safe. The floor is the safe direction: too
    /// long is a card that stays urgent, too short is one that goes calm mid-earthquake.
    func testMissingMagnitudeFallsToTheFloorNotZero() {
        XCTAssertEqual(Activity.gracePeriod(magnitude: 0), 120)
        XCTAssertGreaterThan(Activity.gracePeriod(magnitude: 0), 0)
    }

    // MARK: - isActive

    func testActiveBeforeArrival() {
        let now = Date()
        let arrival = now.addingTimeInterval(30)
        XCTAssertTrue(Activity.isActive(arrivalTime: arrival, magnitude: 5.0, now: now))
    }

    func testStillActiveInsideTheWindow() {
        let now = Date()
        // Landed 90 seconds ago: inside the 2-minute window a M5 gets.
        let arrival = now.addingTimeInterval(-90)
        XCTAssertTrue(Activity.isActive(arrivalTime: arrival, magnitude: 5.0, now: now))
    }

    func testInactiveOnceTheWindowPasses() {
        let now = Date()
        let arrival = now.addingTimeInterval(-121)
        XCTAssertFalse(Activity.isActive(arrivalTime: arrival, magnitude: 5.0, now: now))
    }

    /// The same arrival time is live for a M7 and finished for a M5. This is the whole
    /// point of the change: a bigger rupture shakes for longer.
    func testMagnitudeExtendsTheWindow() {
        let now = Date()
        let arrival = now.addingTimeInterval(-200)
        XCTAssertFalse(Activity.isActive(arrivalTime: arrival, magnitude: 5.0, now: now))
        XCTAssertTrue(Activity.isActive(arrivalTime: arrival, magnitude: 7.0, now: now))
    }

    /// The 1970 default means Firestore has not delivered anything. Treating it as a real
    /// arrival would read as "the wave got here decades ago" and light nothing up - but it
    /// would also make every no-event launch evaluate the window, so it is guarded first.
    func testNoEventIsNeverActive() {
        let epoch = Date(timeIntervalSince1970: 0)
        XCTAssertFalse(Activity.hasEvent(arrivalTime: epoch))
        XCTAssertFalse(Activity.isActive(arrivalTime: epoch, magnitude: 7.0))
    }

    // MARK: - Flashing follows the same window

    /// These were separate - a 15-second flash against a 30-second alert - which left the
    /// countdown quiet while the bar above it was still lit. They are one window now, and
    /// this is what stops them drifting apart again.
    func testFlashingMatchesActive() {
        let now = Date()
        for offset in [30.0, -1, -100, -179, -181, -400] {
            let arrival = now.addingTimeInterval(offset)
            for magnitude in [5.0, 6.5, 7.0] {
                XCTAssertEqual(
                    Activity.isFlashing(arrivalTime: arrival, magnitude: magnitude, now: now),
                    Activity.isActive(arrivalTime: arrival, magnitude: magnitude, now: now),
                    "diverged at offset \(offset), M\(magnitude)")
            }
        }
    }
}
