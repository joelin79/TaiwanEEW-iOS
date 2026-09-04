//
//  MapFraming.swift
//  TaiwanEEW
//
//  What the alert map frames, which depends on the card and on two user preferences.
//
//  The two card positions have different jobs. Expanded is first-person — where am I
//  relative to this earthquake — so it frames on the user whenever it usefully can.
//  Collapsed is an overview of the island, and deliberately ignores where the user is;
//  the point of collapsing the card is to see the map, not yourself on it.
//
//  Note that "the epicenter" means the last one received, not necessarily a current one:
//  EventDispatcher never clears latB/lonB, so after the first report of a session there
//  is always an epicenter, however old. Deliberate — the card is still showing that
//  report, so the map agreeing with it is the consistent choice.
//

import Foundation

/// Expanded, when the user's position cannot usefully anchor the view — no location
/// permission, no fix yet, or a fix that is far from Taiwan. Framing the user together
/// with the epicenter would stretch the box across the sea at a zoom showing neither.
enum AwayFramingPreference: String, CaseIterable, Identifiable {
    /// The earthquake and its surroundings.
    case epicenter
    /// The whole island, ignoring the earthquake.
    case taiwan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .epicenter: return String(localized: "map-framing-epicenter")
        case .taiwan: return String(localized: "map-framing-taiwan")
        }
    }

    static let storageKey = "mapFramingAway"
}

/// Collapsed. Always island-first; the only question is whether an offshore epicenter
/// drags the view out to include itself.
enum CollapsedFramingPreference: String, CaseIterable, Identifiable {
    /// The island box exactly, whatever the earthquake is doing.
    case taiwanOnly
    /// The island box widened until the epicenter fits, which for an offshore event
    /// means zooming out.
    case taiwanAndEpicenter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .taiwanOnly: return String(localized: "map-framing-taiwan-only")
        case .taiwanAndEpicenter: return String(localized: "map-framing-taiwan-epicenter")
        }
    }

    static let storageKey = "mapFramingCollapsed"
}
