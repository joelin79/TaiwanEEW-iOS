//
//  EEWServiceTests.swift
//  TaiwanEEWTests
//
//  Covers the intensity conversions and distance maths that decide what a user is told
//  during an earthquake. These feed the alert copy, the sound chosen by the notification
//  extension, and the countdown, so an off-by-one here is a user-visible safety issue.
//

import XCTest
@testable import TaiwanEEW

final class EEWServiceTests: XCTestCase {

    // MARK: - pgaToIntensity

    /// Boundaries are the interesting part: each band is half-open, so the boundary value
    /// belongs to the higher band. Getting this wrong shifts every alert by one level.
    func testPgaToIntensityBandBoundaries() {
        let cases: [(pga: Double, expected: String)] = [
            (0.0,   "0"),
            (0.79,  "0"),
            (0.8,   "1"),   // boundary belongs to the higher band
            (2.49,  "1"),
            (2.5,   "2"),
            (7.99,  "2"),
            (8.0,   "3"),
            (24.99, "3"),
            (25.0,  "4"),
            (79.99, "4"),
            (80.0,  "5-"),
            (139.9, "5-"),
            (140.0, "5+"),
            (249.9, "5+"),
            (250.0, "6-"),
            (399.9, "6-"),
            (400.0, "6+"),
            (799.9, "6+"),
            (800.0, "7"),
            (5000.0, "7"),
        ]

        for (pga, expected) in cases {
            XCTAssertEqual(EEWService.pgaToIntensity(pga: pga), expected, "pga \(pga)")
        }
    }

    /// The extension maps intensity strings to alarm sounds, so the vocabulary produced
    /// here must stay exactly the set the extension knows about.
    func testPgaToIntensityOnlyProducesKnownStrings() {
        let known: Set<String> = ["0", "1", "2", "3", "4", "5-", "5+", "6-", "6+", "7"]
        for pga in stride(from: 0.0, through: 1000.0, by: 0.5) {
            XCTAssertTrue(known.contains(EEWService.pgaToIntensity(pga: pga)), "pga \(pga)")
        }
    }

    // MARK: - intensity string/value round trip

    func testIntensityStringValueRoundTrip() {
        for value in 1...9 {
            let string = EEWService.intensityValueToString(int: value)
            XCTAssertEqual(
                EEWService.intensityStringToValue(str: string), value,
                "\(value) -> \(string) did not round trip"
            )
        }
    }

    /// 5- and 5+ are distinct levels; collapsing them would under-warn on the stronger one.
    func testWeakAndStrongVariantsAreDistinct() {
        XCTAssertNotEqual(
            EEWService.intensityStringToValue(str: "5-"),
            EEWService.intensityStringToValue(str: "5+")
        )
        XCTAssertNotEqual(
            EEWService.intensityStringToValue(str: "6-"),
            EEWService.intensityStringToValue(str: "6+")
        )
    }

    func testUnknownIntensityIsHandled() {
        XCTAssertEqual(EEWService.intensityStringToValue(str: "garbage"), 0)
        XCTAssertEqual(EEWService.intensityStringToValue(str: ""), 0)
        XCTAssertEqual(EEWService.intensityValueToString(int: 99), "未知")
        XCTAssertEqual(EEWService.intensityValueToString(int: -1), "未知")
    }

    // MARK: - dist

    func testDistanceToSelfIsZero() {
        XCTAssertEqual(EEWService.dist(latA: 25.0, lonA: 121.5, latB: 25.0, lonB: 121.5),
                       0, accuracy: 0.001)
    }

    func testDistanceIsSymmetric() {
        let a = EEWService.dist(latA: 25.03, lonA: 121.56, latB: 22.63, lonB: 120.30)
        let b = EEWService.dist(latA: 22.63, lonA: 120.30, latB: 25.03, lonB: 121.56)
        XCTAssertEqual(a, b, accuracy: 0.001)
    }

    /// Taipei to Kaohsiung is roughly 300 km; a wide tolerance still catches unit errors
    /// (km vs m) or a broken ellipsoid constant.
    func testDistanceTaipeiToKaohsiungIsPlausible() {
        let km = EEWService.dist(latA: 25.033, lonA: 121.565, latB: 22.627, lonB: 120.301)
        XCTAssertGreaterThan(km, 250)
        XCTAssertLessThan(km, 350)
    }

    // MARK: - wave timing

    /// S waves are slower than P waves, which is the entire basis of the warning window.
    func testSWaveIsSlowerThanPWave() {
        for depth in [10.0, 30.0, 50.0, 100.0] {
            for distance in [10.0, 50.0, 150.0] {
                XCTAssertGreaterThan(
                    EEWService.sTime(focalDepth: depth, dist: distance),
                    EEWService.pTime(focalDepth: depth, dist: distance),
                    "depth \(depth), dist \(distance)"
                )
            }
        }
    }

    func testWaveTravelTimeIncreasesWithDistance() {
        let near = EEWService.pTime(focalDepth: 20, dist: 10)
        let far = EEWService.pTime(focalDepth: 20, dist: 200)
        XCTAssertGreaterThan(far, near)
    }
}
