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

    /// Prefix stripped to recover the endpoint suffix, e.g. "…:endpoint".
    static var endpointArnPrefix: String { "\(snsArnPrefix)endpoint" }

    /// Topic ARN for a given topic name, e.g. "…:10501eg3".
    static func topicArn(_ topic: String) -> String { "\(snsArnPrefix)\(topic)" }
}
