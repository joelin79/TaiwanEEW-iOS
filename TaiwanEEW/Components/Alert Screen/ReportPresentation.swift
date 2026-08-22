//
//  ReportPresentation.swift
//  TaiwanEEW
//
//  How an out-of-the-ordinary report is labelled and coloured, in one place.
//
//  The alert screen says this twice — a banner over the map and a badge in the card
//  header — and they had drifted: the banner painted 測試 green while the header painted
//  it amber, and 系統 and 演練 were both pink and so indistinguishable. Same state, two
//  answers. One source removes the possibility.
//
//  Per 強震警報技術文件 xml格式 Ver.2 (103.3.25) the two fields are independent, and
//  getting them the wrong way round is silent — the case simply never fires:
//    status  (事件公告種類) = Actual | Exercise | System | Test
//    msgType (事件公告狀況) = Alert | Update | Cancel | Error
//
//  Narrower than generic CAP 1.2, which also allows status Draft and msgType Ack. CWA
//  emits neither, so do not add cases for them.
//

import SwiftUI

/// The colours a special-case label is drawn in. Foreground is carried with background
/// rather than assumed white: Caution is amber and needs dark text on it.
struct ReportBadge {
    let background: Color
    let foreground: Color
}

/// One half of a report's identity: either what kind of announcement it is, or what it
/// does to the one before it. Both can be present at once — a drill can be cancelled.
///
/// Three lengths from one definition, because the two places this appears have very
/// different room: the banner stacks 中文 over English at full size, the header badge
/// joins them on one line, and a badge showing both halves has to abbreviate or it will
/// not fit beside the magnitude.
struct ReportFacet {
    let chinese: String
    let english: String
    let short: String
    let badge: ReportBadge

    var label: String { "\(chinese) \(english)" }
}

enum ReportPresentation {
    /// Both halves, either of which may be absent. Inputs are lowercased here so callers
    /// do not each have to remember to.
    static func facets(status: String?,
                       msgType: String?,
                       isDebugBuild: Bool = TaiwanEEWApp.DEBUG) -> (status: ReportFacet?, message: ReportFacet?) {
        (statusFacet(status?.lowercased(), isDebugBuild: isDebugBuild),
         messageFacet(msgType?.lowercased()))
    }

    /// The card header's single badge. Ordinary reports get the plain report number and
    /// no badge at all.
    static func headerTitle(status: String?,
                            msgType: String?,
                            eqSeq: Int,
                            isDebugBuild: Bool = TaiwanEEWApp.DEBUG) -> (title: String, badge: ReportBadge?) {
        let facets = facets(status: status, msgType: msgType, isDebugBuild: isDebugBuild)

        switch (facets.status, facets.message) {
        case let (statusFacet?, messageFacet?):
            // Both true at once, so both are shown. The colour follows status: whether the
            // message is real is the fact that must never be misread, and a cancelled
            // drill is still a drill.
            return ("\(statusFacet.short)・\(messageFacet.short)", statusFacet.badge)
        case let (statusFacet?, nil):
            return (statusFacet.label, statusFacet.badge)
        case let (nil, messageFacet?):
            return (messageFacet.label, messageFacet.badge)
        case (nil, nil):
            return ("第 \(eqSeq) 報", nil)
        }
    }

    /// 事件公告種類 — whether this message describes something real.
    private static func statusFacet(_ status: String?, isDebugBuild: Bool) -> ReportFacet? {
        switch status {
        case "exercise":
            // Indigo, ~241°. The banner floats over the intensity map, so the hue wheel is
            // crowded: 0–23° is the red/orange end, 46° is intensity 4, 114° is 3, 183° and
            // 319° are the P and S wave outlines, 221° is 1–2 and 268° is 7. Pink sat near
            // 340°, wedged between the S-wave magenta and the red end — close enough to
            // severity to read as part of it.
            //
            // Indigo lands in the one wide gap that is not a hazard colour anywhere in this
            // app, and its nearest neighbours differ sharply in lightness rather than only
            // in hue: intensity 1 is far darker, intensity 7 far lighter. Cool and clearly
            // synthetic, which is what a drill should look like.
            //
            // The system colour rather than an asset, because it already adapts to dark
            // mode and takes white text in both.
            return ReportFacet(chinese: "演練", english: "Drill", short: "演練",
                               badge: ReportBadge(background: .indigo, foreground: .white))
        case "test" where !isDebugBuild:
            // Amber, so dark text rather than white.
            return ReportFacet(chinese: "測試", english: "Test", short: "測試",
                               badge: ReportBadge(background: Color("Caution"), foreground: .black))
        case "system":
            // The one paired set in the asset catalog that inverts correctly in dark mode.
            return ReportFacet(chinese: "系統", english: "System", short: "系統",
                               badge: ReportBadge(background: Color("SecondaryField"),
                                                  foreground: Color("SecondaryFieldText")))
        default:
            return nil
        }
    }

    /// 事件公告狀況 — what this message does to the one before it. Alert and Update are
    /// both ordinary reports and carry nothing; Update is the common case past 第1報.
    private static func messageFacet(_ msgType: String?) -> ReportFacet? {
        switch msgType {
        case "cancel":
            return ReportFacet(chinese: "預警取消", english: "Canceled", short: "取消",
                               badge: ReportBadge(background: .brown, foreground: .white))
        case "error":
            return ReportFacet(chinese: "預警錯誤", english: "Error", short: "錯誤",
                               badge: ReportBadge(background: .brown, foreground: .white))
        default:
            return nil
        }
    }
}

#Preview("Banner and badge agree") {
    // Both surfaces from the same facets, so a drift between them shows up here.
    // isDebugBuild is forced false: Test is suppressed in debug builds by design.
    let cases: [(String, String?, String?)] = [
        ("actual / alert", "actual", "alert"),
        ("exercise", "exercise", "alert"),
        ("test", "test", "alert"),
        ("system", "system", "alert"),
        ("cancel", "actual", "cancel"),
        ("error", "actual", "error"),
        ("exercise + cancel", "exercise", "cancel"),
        ("test + error", "test", "error"),
    ]

    return ScrollView {
        VStack(spacing: 18) {
            ForEach(cases, id: \.0) { label, status, msgType in
                VStack(spacing: 6) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    ErrorBanner(msgType: msgType, status: status)
                        .padding(.top, -40)
                    Text(ReportPresentation.headerTitle(status: status, msgType: msgType,
                                                        eqSeq: 3, isDebugBuild: false).title)
                        .font(.system(size: 18).bold())
                }
            }
        }
        .padding(.vertical)
    }
    .environment(\.locale, Locale(identifier: "zh-Hant"))
}
