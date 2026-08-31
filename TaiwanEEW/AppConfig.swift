//
//  AppConfig.swift
//  TaiwanEEW
//
//  Reads project configuration injected into Info.plist from Config/Local.xcconfig.
//  No secrets live in this file — the values come from the gitignored xcconfig, so a
//  fork supplies its own by copying Local.xcconfig.example to Local.xcconfig.
//

import Foundation

enum AppConfig {

    /// Fails loudly at launch if a config key is missing or still a placeholder, rather
    /// than silently misbehaving against the wrong backend. Copy Local.xcconfig.example
    /// to Local.xcconfig and fill it in.
    private static func required(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.hasPrefix("your"), !value.hasPrefix("YOUR") else {
            fatalError("Missing config for \(key). Copy Config/Local.xcconfig.example to Config/Local.xcconfig and fill in your values.")
        }
        return value
    }

    static let revenueCatKey = required("RCApiKey")
    static let cognitoPoolID = required("CognitoPoolID")
    static let awsRegion = required("AWSRegion")
    static let awsAccountID = required("AWSAccountID")
    static let snsAppName = required("SNSPlatformAppName")

    /// e.g. "arn:aws:sns:<region>:<account>:"
    static var snsArnPrefix: String { "arn:aws:sns:\(awsRegion):\(awsAccountID):" }

    /// SNS platform application ARN for APNs (production or sandbox).
    static func platformApplicationArn(sandbox: Bool) -> String {
        "\(snsArnPrefix)app/\(sandbox ? "APNS_SANDBOX" : "APNS")/\(snsAppName)"
    }

    // MARK: - APNs environment

    /// The `aps-environment` this build was actually signed with, read from the embedded
    /// provisioning profile: `"development"`, `"production"`, or `"unknown"` when there is
    /// no profile to read (the Simulator) or it cannot be parsed.
    ///
    /// This is the single source of truth for which APNs environment the device token
    /// belongs to. It is deliberately *not* a hand-maintained flag: the entitlement is
    /// rewritten by Xcode at signing time to match the provisioning profile, so a Debug
    /// build to a device is `development` and an archive is `production` whatever anyone
    /// remembered to set. Deriving the SNS platform application from it means the token,
    /// the platform app and the endpoint can no longer disagree — which they silently did,
    /// and a silent disagreement here means no earthquake alerts and no error anywhere.
    static let apsEnvironment: String = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              // isoLatin1 maps every byte, so this never fails on the CMS wrapper's binary.
              let raw = String(data: data, encoding: .isoLatin1),
              let start = raw.range(of: "<?xml"),
              let end = raw.range(of: "</plist>"),
              let plistData = String(raw[start.lowerBound..<end.upperBound]).data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(
                  from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let environment = entitlements["aps-environment"] as? String
        else {
            return "unknown"
        }
        return environment
    }()

    /// Whether this build's device token is a sandbox token.
    ///
    /// Anything we cannot positively identify as `development` is treated as production.
    /// The asymmetry is deliberate: guessing sandbox in a production build would point every
    /// shipped device at the wrong SNS platform application and silence real earthquake
    /// warnings for everyone, while guessing production in a development build only breaks
    /// the developer's own test pushes.
    static var isAPNsSandbox: Bool { apsEnvironment == "development" }

    /// SNS platform application ARN matching how this build was actually signed.
    static var currentPlatformApplicationArn: String {
        platformApplicationArn(sandbox: isAPNsSandbox)
    }

    /// Prefix stripped to recover the endpoint suffix, e.g. "…:endpoint".
    static var endpointArnPrefix: String { "\(snsArnPrefix)endpoint" }

    /// Topic ARN for a given topic name, e.g. "…:10501eg3".
    static func topicArn(_ topic: String) -> String { "\(snsArnPrefix)\(topic)" }
}
