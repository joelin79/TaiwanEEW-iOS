//
//  NotificationLink.swift
//  TaiwanEEW
//
//  The optional `url` a push payload may carry, and the only URL this app opens that it
//  did not compile in itself. Everything in AppLinks is fixed at build time; this arrives
//  over the wire, so it is the one external input that can send a user somewhere.
//
//  Additive by construction: clients that predate this key simply never read it, so the
//  server can start sending `url` without waiting for the installed base to turn over.
//  The key must be omitted entirely when there is no link - an empty string is not the
//  same thing, and would be a value this has to reject rather than a field it can ignore.
//
//  There is deliberately no domain allowlist. A compiled-in list freezes the permitted
//  destinations per release across a long-tailed installed base, so the same push would
//  open on one version and silently do nothing on another - and it would not have bought
//  much: anyone able to inject a payload here could already publish a fake earthquake
//  alert, which is worse than any link. What is left are the two checks that are about the
//  URL itself rather than about which site it names.
//

import Foundation

enum NotificationLink {
    /// The APNs payload key. Kept here so the tests and the tap handler cannot drift.
    static let payloadKey = "url"

    /// The URL to open for this notification, or nil if there isn't one worth opening.
    ///
    /// Every rejection is silent and lands on the same behaviour as a payload with no
    /// `url` at all: the tap just opens the app. A malformed or hostile link should be
    /// indistinguishable from an ordinary notification, not an error the user has to read.
    static func destination(from userInfo: [AnyHashable: Any]) -> URL? {
        // APNs payloads are JSON, so this key can arrive as a number or a nested object
        // just as easily as a string. A forced cast would trap on a server-side mistake.
        guard let raw = userInfo[payloadKey] as? String,
              let components = URLComponents(string: raw) else { return nil }

        // The check that carries the weight. Without it the payload could name a custom
        // scheme and reach another app's deep-link handler, or file: and javascript: in
        // anything that later renders it. Compared case-insensitively because schemes are
        // case-insensitive per RFC 3986 and Foundation does not promise to normalize them.
        guard components.scheme?.lowercased() == "https" else { return nil }

        // `https://www.cwa.gov.tw@evil.com` parses with host evil.com and the trusted name
        // as the userinfo section. Anything that renders the string - a notification body,
        // a URL bar mid-load - reads as the trusted site while the request goes elsewhere.
        guard components.user == nil, components.password == nil else { return nil }

        // A scheme with nothing after it is not somewhere anyone can be sent.
        guard let host = components.host, !host.isEmpty else { return nil }

        return components.url
    }
}
