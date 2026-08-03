# Changelog

Public App Store releases. Dates are the release-tag dates in this repository.

## 2.1.0 — 2026-07-28

- Auto-location: automatically switches your alert district as you move, with background
  updates.
- Distinct alarm sounds per predicted intensity, via a notification service extension;
  critical alerts keep bypassing silent mode and Focus.
- Dedicated Support (donation) tab.
- Notification and location permission status surfaced in Settings, with one-tap links to
  fix them.
- Subscription recovery hardened: reconnects topics after a device restore, transfer or
  reinstall (APNs token rotation) instead of going silently unsubscribed.
- Fixes: iOS 26 donation page dismissing itself; version-topic being unsubscribed when the
  alert level was set to off; being unable to pick a district while location was denied.

## 2.0.8 — 2026-07-20

- Donation UI fixes and a workaround for an iOS 26 SwiftUI sheet regression.

## 2.0.7 — 2026-05-02

- Fix for the iOS 26.3 sheet presentation regression.

## 2.0.6 — 2026-04-08

- In-app donations via RevenueCat.

## 2.0.5 — 2024-11-04

- Red highlight for intensity 4 and above.

## 2.0.4 — 2024-09-07

- Display and layout fixes.

---

Development history before open-sourcing is retained in the original private repository.
This public repository starts fresh at 2.1.0.
