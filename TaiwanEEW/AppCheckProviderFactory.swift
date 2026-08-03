//
//  AppCheckProviderFactory.swift
//  TaiwanEEW
//
//  Supplies the Firebase App Check attestation provider. Installed before
//  FirebaseApp.configure() so every Firebase request carries an App Check token.
//
//  Rollout: App Check is registered in the Firebase console but left UNENFORCED. Enforcing
//  it would immediately reject every client in the field that has no token — i.e. every
//  build before this one — so their in-app live earthquake view (Firestore) would stop
//  updating. Push alerts are unaffected (SNS/APNs, not Firebase). Only enforce in the
//  console once App Check metrics show verified traffic is high enough, meaning most users
//  have upgraded.
//

import Foundation
import FirebaseAppCheck
import FirebaseCore
import DeviceCheck

final class TaiwanEEWAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        // Simulators and dev devices can't attest. The debug provider prints a token on first
        // launch; register it in Firebase console → App Check → Manage debug tokens if App
        // Check is ever enforced. Harmless while unenforced.
        return AppCheckDebugProvider(app: app)
        #else
        // App Attest needs a Secure Enclave (A12+, iOS 14+). The app supports iOS 15.4, which
        // still runs on pre-A12 devices; those fall back to DeviceCheck so they can still
        // produce a valid token once App Check is enforced.
        if #available(iOS 14.0, *), DCAppAttestService.shared.isSupported {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
        #endif
    }
}
