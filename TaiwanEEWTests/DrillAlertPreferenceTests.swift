//
//  DrillAlertPreferenceTests.swift
//  TaiwanEEWTests
//
//  Covers the predicate that decides whether a push is delivered silently. It runs inside
//  the notification service extension, where nothing is observable and a mistake is only
//  discovered by someone not hearing an earthquake warning - so every branch is pinned here.
//

import XCTest
@testable import TaiwanEEW

final class DrillAlertPreferenceTests: XCTestCase {

    private typealias Pref = DrillAlertPreference

    // MARK: - Real alerts are never silenced

    /// The one that matters. Whatever the user asked for, an Actual report is a real
    /// earthquake and must keep its sound and its critical interruption level.
    func testActualIsNeverSilenced() {
        XCTAssertFalse(Pref.shouldSilence(status: "Actual", isMuted: true))
    }

    /// CWA's casing is not a contract, and the extension lowercases before comparing.
    /// If that ever stopped happening, "actual" would read as non-Actual and a real
    /// warning would arrive silently.
    func testActualIsMatchedCaseInsensitively() {
        XCTAssertFalse(Pref.shouldSilence(status: "actual", isMuted: true))
        XCTAssertFalse(Pref.shouldSilence(status: "ACTUAL", isMuted: true))
    }

    // MARK: - Non-actual reports

    func testNonActualStatusesAreSilenced() {
        for status in ["Exercise", "System", "Test"] {
            XCTAssertTrue(Pref.shouldSilence(status: status, isMuted: true),
                          "\(status) is not a real earthquake and should be silenced")
        }
    }

    func testNonActualIsMatchedCaseInsensitively() {
        XCTAssertTrue(Pref.shouldSilence(status: "exercise", isMuted: true))
    }

    /// Deliberately "not Actual" rather than a list of the three known statuses, so a status
    /// CWA introduces later defaults to silent rather than to a full critical alarm.
    func testUnknownStatusIsTreatedAsNonActual() {
        XCTAssertTrue(Pref.shouldSilence(status: "SomethingNew", isMuted: true))
    }

    // MARK: - Cases where we cannot tell, and must not guess

    /// Every payload from a backend predating the `status` field. If this returned true the
    /// feature would have silenced real warnings from the moment it shipped, for as long as
    /// it took the server to catch up.
    func testAbsentStatusFallsThroughToAlerting() {
        XCTAssertFalse(Pref.shouldSilence(status: nil, isMuted: true))
    }

    /// The sharper edge of the same problem. `Earthquake.status` on the server is read
    /// straight out of the CWA XML, so a malformed document can yield an empty string - and
    /// "" != "actual" is true. Without the emptiness guard this silences a real alert.
    func testBlankStatusFallsThroughToAlerting() {
        XCTAssertFalse(Pref.shouldSilence(status: "", isMuted: true))
        XCTAssertFalse(Pref.shouldSilence(status: "   ", isMuted: true))
        XCTAssertFalse(Pref.shouldSilence(status: "\n", isMuted: true))
    }

    // MARK: - The preference is honoured

    /// Opt-out only. A user who never touched the setting hears the drill exactly as before.
    func testNothingIsSilencedWhenThePreferenceIsOff() {
        for status in ["Actual", "Exercise", "System", "Test", "SomethingNew"] {
            XCTAssertFalse(Pref.shouldSilence(status: status, isMuted: false),
                           "\(status) must alert normally when the user has not opted out")
        }
        XCTAssertFalse(Pref.shouldSilence(status: nil, isMuted: false))
    }

    // MARK: - Shared container contract

    /// The suite name and key are duplicated in both targets' entitlements and read by a
    /// separate process. Renaming either silently detaches the extension from the setting:
    /// the toggle would appear to work while every drill still arrived at full volume.
    func testSharedSuiteIdentifiersAreStable() {
        XCTAssertEqual(Pref.suiteName, "group.com.joedev.TaiwanEEW")
        XCTAssertEqual(Pref.storageKey, "drillAlertsMuted")
    }
}
