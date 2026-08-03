//
//  NotificationTopicTests.swift
//  TaiwanEEWTests
//
//  Covers the topic-name rules that decide which SNS topics a device is subscribed to.
//  A regression here is invisible at runtime - the app keeps working, it just stops
//  receiving the alerts it believes it is subscribed to - so it is worth pinning down.
//

import XCTest
@testable import TaiwanEEW

final class NotificationTopicTests: XCTestCase {

    private typealias AWS = NotificationManager.AWSManager

    // MARK: - versionTopic(for:)

    func testVersionTopicForReleaseVersion() {
        XCTAssertEqual(AWS.versionTopic(for: "2.1.0"), "ver2_1_0")
        XCTAssertEqual(AWS.versionTopic(for: "2.0.8"), "ver2_0_8")
    }

    /// The TestFlight builds used a four-digit patch; it must map to its own topic and
    /// not silently collapse into the release topic.
    func testVersionTopicKeepsMultiDigitPatch() {
        XCTAssertEqual(AWS.versionTopic(for: "2.1.002"), "ver2_1_002")
        XCTAssertNotEqual(AWS.versionTopic(for: "2.1.002"), AWS.versionTopic(for: "2.1.0"))
    }

    /// A two-component marketing version is legal in Xcode, so it must not crash or
    /// produce a truncated topic - the missing patch defaults to 0.
    func testVersionTopicPadsMissingPatch() {
        XCTAssertEqual(AWS.versionTopic(for: "2.2"), "ver2_2_0")
    }

    func testVersionTopicIgnoresComponentsBeyondPatch() {
        XCTAssertEqual(AWS.versionTopic(for: "2.1.0.4"), "ver2_1_0")
    }

    // MARK: - isThresholdManagedTopic

    /// District topics are owned by the threshold and may be unsubscribed when it changes.
    func testDistrictTopicsAreThresholdManaged() {
        for level in 0...4 {
            XCTAssertTrue(AWS.isThresholdManagedTopic("10501eg\(level)"))
        }
        XCTAssertTrue(AWS.isThresholdManagedTopic("12301eg3"))
    }

    /// The off reminder topic is also threshold-owned: switching away from off must
    /// unsubscribe it.
    func testOffTopicIsThresholdManaged() {
        XCTAssertTrue(AWS.isThresholdManagedTopic("off"))
    }

    /// The regression this rule exists to prevent: changing threshold or district must
    /// never unsubscribe a version topic, or the device silently drops off version
    /// announcements until the next cold launch.
    func testVersionTopicsAreNotThresholdManaged() {
        XCTAssertFalse(AWS.isThresholdManagedTopic("ver2_1_0"))
        XCTAssertFalse(AWS.isThresholdManagedTopic("ver2_0_1"))
        XCTAssertFalse(AWS.isThresholdManagedTopic("ver2_1_002"))
    }

    /// Anything unrecognised is left alone rather than unsubscribed, so an unknown topic
    /// added server-side is not destroyed by a threshold change.
    func testUnrecognisedTopicsAreNotThresholdManaged() {
        XCTAssertFalse(AWS.isThresholdManagedTopic("test"))
        XCTAssertFalse(AWS.isThresholdManagedTopic(""))
        XCTAssertFalse(AWS.isThresholdManagedTopic("1050eg3"))    // 4-digit district
        XCTAssertFalse(AWS.isThresholdManagedTopic("105010eg3"))  // 6-digit district
        XCTAssertFalse(AWS.isThresholdManagedTopic("10501eg"))    // no level
        XCTAssertFalse(AWS.isThresholdManagedTopic("10501eg33"))  // two-digit level
    }

    // MARK: - generateTopicKeys

    /// A threshold subscribes its own level and every level above it, so a user asking for
    /// intensity 3 still hears about a 4. Extra alerts are acceptable; missing one is not.
    func testThresholdSubscribesItsLevelAndAbove() {
        let topics = AWS.generateTopicKeys(for: 0, districtIndex: 0, threshold: .eg3)
        let code = Location.cities[0].district[0].getTopicCode()

        XCTAssertEqual(topics, ["\(code)eg3", "\(code)eg4"])
    }

    func testLowestThresholdSubscribesAllLevels() {
        let topics = AWS.generateTopicKeys(for: 0, districtIndex: 0, threshold: .eg0)
        XCTAssertEqual(topics.count, 5, "eg0 should cover levels 0 through 4")
    }

    func testHighestThresholdSubscribesOnlyTopLevel() {
        let topics = AWS.generateTopicKeys(for: 0, districtIndex: 0, threshold: .eg4)
        XCTAssertEqual(topics.count, 1)
        XCTAssertTrue(topics[0].hasSuffix("eg4"))
    }

    /// Off subscribes only the reminder topic - and notably no district topics, which is
    /// what makes the threshold-managed filter necessary.
    func testOffSubscribesOnlyTheOffTopic() {
        let topics = AWS.generateTopicKeys(for: 0, districtIndex: 0, threshold: .off)
        XCTAssertEqual(topics, ["off"])
    }

    /// Every generated district topic must itself be threshold-managed, otherwise
    /// setNotifyMode would leave stale district subscriptions behind on a change.
    func testGeneratedDistrictTopicsAreAllThresholdManaged() {
        for threshold in [NotifyThreshold.eg0, .eg1, .eg2, .eg3, .eg4, .off] {
            for topic in AWS.generateTopicKeys(for: 0, districtIndex: 0, threshold: threshold) {
                XCTAssertTrue(
                    AWS.isThresholdManagedTopic(topic),
                    "\(topic) is generated by the threshold but would not be cleaned up by it"
                )
            }
        }
    }
}
