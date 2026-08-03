# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Keep the Current Status and Roadmap sections below up to date as work lands.**

> `NOTES.private.md` (gitignored, local only) holds the full task list plus security
> specifics, the credentials inventory, and open-source planning — anything not suitable for
> a public repo. Read it alongside this file when picking up work, and keep the two in sync:
> details there, sanitized summary here. This repo is intended to be open-sourced, so treat
> everything in CLAUDE.md as publishable.

## Project Overview

Taiwan EEW (地震速報) is an iOS earthquake early warning application that provides real-time earthquake alerts for Taiwan. The app receives earthquake data from the Central Weather Administration (CWA) and displays warnings with arrival time countdowns, intensity predictions, and location-based notifications.

Companion backend (separate private repo): `TaiwanEEW-Server-Java`, production runs on the `gradle` branch. It watches CWA XML, computes per-district intensity, publishes to AWS SNS topics, and writes events to Firestore.

## Current Status

Last updated: 2026-07-28

- **Released:** 2.1.0 (build 12), tagged `v2.1.0`, merged to `main` via PR #39, submitted to App Store.
- **Branching:** trunk-based. `main` is the only long-lived branch; releases are pinned by tags (`v2.0.4` … `v2.1.0`). Feature work branches off `main` and merges back quickly.
- **Installed base is long-tailed** — users remain on 2.0.4 through 2.0.8. Never assume only the newest client is live; see Compatibility Rules below.

2.1.0 was a large release: it merged ~16 months of unshipped trunk work (auto-location, notification service extension, NotificationManager rewrite) with the 2.0.6–2.0.8 hot-release line that shipped RevenueCat IAP.

## Build Commands

### Development Setup
1. Open the workspace (not the xcodeproj):
   ```bash
   open TaiwanEEW.xcworkspace
   ```

2. Build:
   ```bash
   xcodebuild -workspace TaiwanEEW.xcworkspace -scheme TaiwanEEW -configuration Debug
   ```

3. Test (⌘U in Xcode, or):
   ```bash
   xcodebuild test -workspace TaiwanEEW.xcworkspace -scheme TaiwanEEW \
     -destination 'platform=iOS Simulator,name=iPhone 16'
   ```

> **Do not run `pod install`.** CocoaPods is integrated but resolves to **zero** pods —
> `Podfile.lock` has no `PODS:` section and `Pods/` contains no dependencies. All
> dependencies come from SPM. The `Podfile` still lists three Firebase pods that were
> never installed; running `pod install` would install them _on top of_ the SPM copies
> and cause duplicate symbols. Removing CocoaPods entirely is a queued task.

### Project Configuration

- Minimum iOS deployment target: 15.4 (app, extension, and test target)
- Dependencies: **Swift Package Manager only** (see Dependencies below)
- Bundle identifier: `com.joedev.TaiwanEEW`
- Targets: `TaiwanEEW`, `TaiwanEEWServiceExtension`, `TaiwanEEWTests`
- **Setup:** copy `Config/Local.xcconfig.example` → `Config/Local.xcconfig` and
  `TaiwanEEW/GoogleService-Info.plist.example` → `TaiwanEEW/GoogleService-Info.plist`,
  then fill in your own team ID, Firebase, AWS and RevenueCat values. Both real files are
  gitignored. `AppConfig` reads the injected values at runtime and fails loudly if any is missing.
- App and extension **must** share the same marketing version and build number, or App Store validation rejects the upload. Xcode's Version/Build fields only write the selected target — bump both.

## Architecture Overview

### Core Services Layer

**EEWService** (`TaiwanEEW/EEWService.swift`)
- Provides seismological calculations for earthquake wave propagation
- Key functions:
  - `pTime()` / `sTime()`: Calculate P-wave and S-wave arrival times using velocity models
  - `pgaToIntensity()`: Convert Peak Ground Acceleration (PGA) to seismic intensity scale
  - `dist()`: Calculate distance between geographic coordinates using Taiwan-specific ellipsoid parameters
- Wave velocity models switch behavior at 40km depth threshold

**EventDispatcher** (`TaiwanEEW/EventDispatcher.swift`)
- Observable object that manages earthquake event state
- Subscribes to Firebase Firestore collection "EEW" for real-time earthquake data
- Calculates local intensity and arrival times based on user's subscribed location
- Calls `findMaxIntensity()` to compute maximum predicted intensity across all Taiwan districts
- Also monitors "ping" collection for service health checks

**LocationManager** (`TaiwanEEW/LocationManager.swift`)
- Singleton manager for auto-location feature with background update support
- Uses BGAppRefreshTask for periodic background location updates (30-minute intervals)
- Implements battery optimization via stationary detection (reduces accuracy when user hasn't moved >100m in 10 minutes)
- Matches user coordinates to closest district from `Location.cities` data
- Triggers subscription updates when location changes to different district
- IMPORTANT: Location changes update subscriptions through the coordinated `onLocationChanged` callback to prevent double subscriptions

**NotificationManager** (`TaiwanEEW/NotificationManager.swift`)
- Manages AWS SNS and Firebase Cloud Messaging subscriptions
- AWS SNS is the primary notification service; FCM is deprecated ("珍惜生命,遠離 FCM")
- Topic structure: `{districtID}eg{intensity}` (e.g., "10201eg3" for Taipei Songshan district intensity 3+)
- Subscribes to version-specific topics (e.g., "ver2_1_0") for app updates
- Implements subscription state validation and recovery on app launch
- CRITICAL: All subscription operations are async and use an operation queue to prevent race conditions

### Data Models

**Location** (`TaiwanEEW/Models/Location.swift`)
- Static data structure containing all Taiwan city/district coordinates
- Each district has: ID, longitude, latitude, site amplification factor (si), and localized name
- Site amplification factor (si) is used in PGA calculations for local intensity prediction
- Provides `selectionFromID()` for converting district IDs to array indices
- Contains `polygonIDMapping` for mapping CWA polygon IDs to district IDs

**EEWReport** (`TaiwanEEW/Models/EEWReport.swift`)
- Codable model for earthquake early warning reports from Firestore
- Key fields: originTime, sent (publish time), epicenterLat/Lon, magnitudeValue, depth, msgNo (sequence), pgaAdj
- pgaAdj is an adjustment factor for PGA calculations specific to each earthquake

### UI Architecture

**TaiwanEEWApp** (`TaiwanEEW/TaiwanEEWApp.swift`)
- Main app entry point with AppDelegate for notification handling
- TabView: AlertView, HistoryView (debug only), DonateView, SettingsView
- Uses @AppStorage for persistence: subscribedCityIndex, subscribedDistrictIndex, notifyThreshold
- First launch flow shows `FirstLaunchView` before main interface
- Notification taps carrying `NotificationManager.deepLinkKey` open the app's iOS Settings page
- IMPORTANT: Auto-location callback updates @AppStorage values which triggers NotificationManager subscription updates

**DonateView** (`TaiwanEEW/Pages/DonateView.swift`)
- Reached two ways: its own tab, and modally from SettingsView
- `showsDismissControls` hides the close/cancel buttons in the tab presentation
- Donation options are presented as a **pushed page**, not a sheet: on iOS 26.x a SwiftUI
  regression dismisses sheets when the parent re-renders. Do not revert to `.sheet`.

**Notification Service Extension** (`TaiwanEEWServiceExtension/`)
- Reads the `ins` field from the APNs payload and swaps in the matching intensity alarm sound
- Uses `criticalSoundNamed` for critical alerts so they keep bypassing silent mode and Focus
- Payloads without `ins` fall through to the sound already in the payload

**AlertView** (`TaiwanEEW/Pages/AlertView.swift`)
- Primary screen showing current earthquake warnings
- Displays countdown to S-wave arrival, predicted intensity, and earthquake details
- Uses EventDispatcher for real-time data updates

**SettingsView** (`TaiwanEEW/Pages/SettingsView.swift`)
- Location subscription management (manual district selection or auto-location)
- Notification threshold settings (intensity 1-4 or off)
- Callbacks trigger subscription updates via NotificationManager

### Background Processing

**BGAppRefreshTask Registration**
- Registered in `AppDelegate.didFinishLaunching` via `LocationManager.registerBackgroundTasks()`
- Identifier: "com.joedev.TaiwanEEW.locationUpdate"
- Scheduled every 30 minutes when auto-location is enabled
- Updates location and district subscription in background

## Critical Implementation Details

### Debug Mode

- Static flag: `TaiwanEEWApp.DEBUG`
- When true: Shows HistoryView tab, sends debug notifications, uses sandbox APNs
- When false: Production APNs, no debug UI

### Notification System

- AWS SNS Platform Application ARNs differ for debug/production
- Topic subscription is stateful and persisted in UserDefaults: "AWSsubscribedTopics", "subscriptionsARN"
- Subscription recovery runs on app launch and after endpoint creation
- NEVER skip hooks (--no-verify) or force destructive operations

### Seismological Constants

- P-wave velocity model: G0=5.10298, G=0.06659 (depth ≤ 40km); G0=7.804799, G=0.004573 (depth > 40km)
- S-wave velocity: P-wave velocity / 1.732
- Intensity scale: 0, 1, 2, 3, 4, 5-, 5+, 6-, 6+, 7 (mapped to int values 0-9)

### Firebase Integration

- Security rules deny all client writes and cap list reads. **Adding a Firestore collection
  the app reads requires adding a matching rule block** (`allow get`/`list`/`write: if false`)
  in the same change, or it silently returns empty data — no crash. Same applies to Realtime
  Database and Storage.
- Firestore collections: "EEW" (earthquake events), "ping" (health checks)
- FCM is configured but token is explicitly deleted in AppDelegate
- Firebase Analytics tracks user properties: subscribedCity, subscribedDistrict, notifyThreshold

### Auto-Location Subscription Flow
1. LocationManager detects location change
2. Finds closest district via `findClosestDistrict()`
3. Calls `onLocationChanged` callback
4. TaiwanEEWApp updates @AppStorage variables
5. @AppStorage change triggers `NotificationManager.setNotifyMode()`
6. NotificationManager subscribes to new district topics and unsubscribes from old

This coordinated flow prevents double subscriptions that were a previous bug.

## Localization

The app supports multiple languages (en, zh-Hant, ja) with localized strings for:
- Navigation labels (nav-alert-string, nav-history-string, nav-settings-string)
- City names (via LocalizedStringKey in Location.City.getDisplayName())
- Intensity values and earthquake details

## Dependencies

All dependencies come from **Swift Package Manager**. CocoaPods is still integrated into the
project but installs nothing — see the warning under Build Commands.

- Firebase iOS SDK — Firestore, Messaging, Analytics, Crashlytics
- AWS SDK iOS SPM — SNS for notifications, Cognito for unauthenticated credentials
- RevenueCat (`purchases-ios-spm`) — in-app donations
- XMLCoder — XML parsing for CWA data

> Known issue: the RevenueCat pin differs between `TaiwanEEW.xcworkspace/…/Package.resolved`
> (5.61.0, what the build actually uses) and `TaiwanEEW.xcodeproj/…/Package.resolved` (5.81.2).
> Unifying these is a queued task.

## Compatibility Rules

The installed base spans several versions and old clients stay in the field for a long time.
Anything touching notifications, subscriptions, or persisted state must assume old clients
are still live.

- **SNS topic names are the contract.** `{districtID}eg{0-4}`, plus `off` and `ver{major}_{minor}_{patch}`. Renaming any of these silently stops alerts for clients that still subscribe to the old name.
- **Create the version topic before releasing.** 2.1.0 needs `ver2_1_0`, 2.1.1 needs `ver2_1_1`. A missing topic means a failed subscribe on every launch for that build.
- **Version topics are not owned by the notification threshold.** `isThresholdManagedTopic()` decides what a threshold change may unsubscribe; only district topics and `off` qualify. Broadening it would drop users off version announcements.
- **Backend payload changes must be additive.** Old clients ignore unknown fields; they must never depend on a field being present. The `ins` field degrades gracefully — clients without the extension just use the payload's sound.
- **UserDefaults keys are a migration surface.** Renaming `subscribedCityIndex`, `notifyThreshold`, `AWSsubscribedTopics`, `subscriptionsARN` or `endpointArnForSNS` would silently reset users. Migrations should be state-based and idempotent, never "assume the previous version ran".

## Testing

- Unit tests live in `TaiwanEEWTests/` (22 tests): topic-name rules in `NotificationTopicTests`, intensity/distance maths in `EEWServiceTests`
- Run with ⌘U or `xcodebuild test` (see Build Commands)
- Mock data available in `TaiwanEEW/Models/MockData.swift`
- Seismic calculations can be verified with known earthquake events

### What unit tests cannot cover

These need a physical device and are the highest-risk areas — verify manually before release:

- Critical alert delivery and mute-switch bypass
- APNs token rotation and subscription recovery (restore from backup / reinstall)
- Upgrade from an older build with settings preserved
- Background location district switching
- RevenueCat purchase and restore (sandbox)

> Building from Xcode always yields a **sandbox** APNs token. The three links —
> `aps-environment`, `TaiwanEEWApp.DEBUG` (which picks the SNS platform app), and the
> backend's `sandbox:` flag — must all agree or pushes silently vanish. Use TestFlight to
> exercise the production chain.

## Roadmap

Next release (2.1.1) and ongoing cleanup, roughly in priority order.

### Hardening

- Firebase App Check — integrate unenforced, monitor verified traffic, enforce only after adoption (enforcing early breaks every client in the field)
- Tighten Firebase security rules and add billing alerts
- Review the Cognito unauthenticated role's permissions

### Cleanup

- Remove CocoaPods entirely: `Podfile`, `Pods/`, the empty `Pods_TaiwanEEW.framework`, the `[CP]` build phase, the xcconfig base configurations, and the workspace; switch CI and this file to the `.xcodeproj`
- Unify the RevenueCat SPM version
- Prepare for open source: externalize `GoogleService-Info.plist` and other configuration, gitignore and untrack `.DS_Store`/`xcuserdata`, add LICENSE / README / SECURITY.md

### Features

- First-launch onboarding: terms → notification permission → location or manual region. Today a fresh install silently defaults to the first district in the list, so a user who never opens Settings gets alerts for the wrong region
- Background App Refresh status in the auto-location block, with a Settings deep link
- Optional web URL in the notification payload, opened on tap (needs a matching backend change)
- User location pin on the map
- City-level geojson overlay with thicker lines above the district layer
- Auto-disable EEW when the nearest district is >100 km away (changes alert delivery — needs careful design and its own test pass)

### Known issues

- Purchase analytics: the resubscribe guard calls `getCustomerInfo` and discards its error, so a network failure causes the event to log anyway. Dedupe on transaction ID instead
- Donation fallback prices are hardcoded in TWD, so a non-TW user sees the wrong currency if RevenueCat offerings fail to load
- TestFlight/sandbox builds display IAP prices in USD while charging correctly in TWD; production is unaffected
