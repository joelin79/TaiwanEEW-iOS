//
//  PurchaseManager.swift
//  TaiwanEEW
//

import Foundation
import RevenueCat

enum RestoreResult: Equatable {
    case success, noActiveSubscriptions, failed(String)
}

class PurchaseManager: ObservableObject {
    @Published var packages: [Package] = []
    @Published var isFetching = false
    @Published var purchaseSucceeded = false
    @Published var restoreResult: RestoreResult? = nil
    
    init() {
        fetchOfferings()
    }
    
    func fetchOfferings() {
        isFetching = true
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            DispatchQueue.main.async {
                self?.isFetching = false
                if let error = error {
                    print("Error fetching offerings: \(error.localizedDescription)")
                }
                
                if let offerings = offerings?.current {
                    self?.packages = offerings.availablePackages
                }
            }
        }
    }
    
    func restorePurchases() {
        isFetching = true
        Purchases.shared.restorePurchases { [weak self] (customerInfo, error) in
            DispatchQueue.main.async {
                self?.isFetching = false
                if let error = error {
                    self?.restoreResult = .failed(error.localizedDescription)
                    AnalysicsManager.shared.logEvent(name: "restore_purchase_failed", params: [
                        "error_message": error.localizedDescription
                    ])
                } else if customerInfo?.activeSubscriptions.isEmpty == true {
                    self?.restoreResult = .noActiveSubscriptions
                    AnalysicsManager.shared.logEvent(name: "restore_purchase_not_found")
                } else {
                    self?.restoreResult = .success
                    AnalysicsManager.shared.logEvent(name: "restore_purchase_success")
                }
            }
        }
    }

    func purchase(_ package: Package) {
        isFetching = true
        Purchases.shared.purchase(package: package) { [weak self] (transaction, customerInfo, error, userCancelled) in
            DispatchQueue.main.async {
                self?.isFetching = false
                if let error = error {
                    print("Purchase failed: \(error.localizedDescription)")
                    AnalysicsManager.shared.logEvent(name: "purchase_failed", params: [
                        "package_id": package.identifier,
                        "error_message": error.localizedDescription
                    ])
                } else if userCancelled {
                    print("User cancelled purchase")
                    AnalysicsManager.shared.logEvent(name: "purchase_cancelled", params: [
                        "package_id": package.identifier
                    ])
                } else {
                    print("Purchase successful!")
                    self?.purchaseSucceeded = true
                    // Deduplicate on the StoreKit transaction id: buying an already-active
                    // product returns the existing transaction (same id), so it is not logged
                    // twice. This replaces a pre-purchase getCustomerInfo check that discarded
                    // its error and so logged the event anyway whenever that call failed.
                    if let transactionId = transaction?.transactionIdentifier,
                       !Self.hasLoggedPurchase(transactionId) {
                        Self.markPurchaseLogged(transactionId)
                        let price = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue
                        let currency = package.storeProduct.currencyCode ?? "TWD"
                        AnalysicsManager.shared.logEvent(name: "purchase", params: [
                            "transaction_id": transactionId,
                            "value": price,
                            "currency": currency,
                            "items": [[
                                "item_id": package.identifier,
                                "item_name": package.identifier,
                                "price": price,
                                "quantity": 1
                            ]]
                        ])
                    }
                }
            }
        }
    }

    // MARK: - Purchase-event de-duplication
    // Persist the StoreKit transaction ids already logged to Analytics, so the "purchase"
    // event is never double-counted (e.g. StoreKit returning an existing transaction).
    private static let loggedPurchasesKey = "loggedPurchaseTransactionIDs"

    static func hasLoggedPurchase(_ transactionId: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: loggedPurchasesKey) ?? []).contains(transactionId)
    }

    static func markPurchaseLogged(_ transactionId: String) {
        var logged = UserDefaults.standard.stringArray(forKey: loggedPurchasesKey) ?? []
        guard !logged.contains(transactionId) else { return }
        logged.append(transactionId)
        // Cap the stored list so it cannot grow without bound.
        if logged.count > 100 { logged.removeFirst(logged.count - 100) }
        UserDefaults.standard.set(logged, forKey: loggedPurchasesKey)
    }
}
