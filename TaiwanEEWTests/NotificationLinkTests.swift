//
//  NotificationLinkTests.swift
//  TaiwanEEWTests
//
//  Covers the one place the app opens a URL it did not choose itself. Everything else it
//  opens comes from AppLinks, compiled in; this comes off the wire in a push payload, so
//  it is the only external input that can send a user somewhere.
//
//  There is deliberately no domain allowlist - a compiled-in list freezes the permitted
//  destinations per release across a long-tailed installed base, and anyone able to inject
//  a payload could already publish a fake earthquake alert, which is worse. What is left
//  are the two checks that are about the URL itself rather than about which site it names:
//  the scheme must be https, and the URL must not carry credentials.
//

import XCTest
@testable import TaiwanEEW

final class NotificationLinkTests: XCTestCase {

    private typealias Link = NotificationLink

    private func userInfo(_ value: Any) -> [AnyHashable: Any] {
        [Link.payloadKey: value]
    }

    // MARK: - The happy path

    func testValidHTTPSLinkIsReturned() {
        let url = Link.destination(from: userInfo("https://discord.com/invite/JfEsU3mx3U"))
        XCTAssertEqual(url?.absoluteString, "https://discord.com/invite/JfEsU3mx3U")
    }

    /// Schemes are case-insensitive per RFC 3986, and Foundation does not promise to
    /// normalize them, so a server that sends HTTPS must not be silently ignored.
    func testSchemeComparisonIsCaseInsensitive() {
        XCTAssertNotNil(Link.destination(from: userInfo("HTTPS://discord.com/x")))
    }

    // MARK: - Scheme

    /// The check that actually matters. Without it the payload could name a custom scheme
    /// and reach another app's deep-link handler, or javascript: in any web context.
    func testNonHTTPSSchemesAreRejected() {
        XCTAssertNil(Link.destination(from: userInfo("http://discord.com/x")),
                     "cleartext http must not open")
        XCTAssertNil(Link.destination(from: userInfo("javascript:alert(1)")),
                     "javascript: must not open")
        XCTAssertNil(Link.destination(from: userInfo("file:///etc/passwd")),
                     "file: must not open")
        XCTAssertNil(Link.destination(from: userInfo("taiwaneew://settings")),
                     "a custom scheme must not open")
    }

    // MARK: - Credentials

    /// `https://www.cwa.gov.tw@evil.com` parses with host evil.com and user www.cwa.gov.tw.
    /// Anything that renders the string - a notification body, a browser's URL bar mid-load -
    /// reads as the trusted site while the request goes elsewhere.
    func testCredentialsAreRejected() {
        XCTAssertNil(Link.destination(from: userInfo("https://www.cwa.gov.tw@evil.com/x")),
                     "a host-spoofing userinfo section must not open")
        XCTAssertNil(Link.destination(from: userInfo("https://user:pass@discord.com/x")),
                     "an explicit username and password must not open")
    }

    // MARK: - Malformed and absent

    func testMissingKeyReturnsNil() {
        XCTAssertNil(Link.destination(from: [:]))
        XCTAssertNil(Link.destination(from: ["ins": "4", "status": "Actual"]))
    }

    /// APNs payloads are JSON, so a number or a nested object is a perfectly possible
    /// value for this key. Casting without checking would trap.
    func testNonStringValueReturnsNil() {
        XCTAssertNil(Link.destination(from: userInfo(42)))
        XCTAssertNil(Link.destination(from: userInfo(["nested": "object"])))
    }

    func testEmptyOrUnparseableStringReturnsNil() {
        XCTAssertNil(Link.destination(from: userInfo("")))
        XCTAssertNil(Link.destination(from: userInfo("   ")))
        XCTAssertNil(Link.destination(from: userInfo("not a url at all")))
    }

    /// A scheme with nothing after it is not somewhere anyone can be sent.
    func testURLWithoutAHostIsRejected() {
        XCTAssertNil(Link.destination(from: userInfo("https://")))
        XCTAssertNil(Link.destination(from: userInfo("https:///path-only")))
    }
}
