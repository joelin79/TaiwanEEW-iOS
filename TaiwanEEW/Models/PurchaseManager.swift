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
        Purchases.shared.getCustomerInfo { [weak self] (preInfo, _) in
            let activeBeforePurchase = preInfo?.activeSubscriptions ?? []
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
                        let productId = package.storeProduct.productIdentifier
                        let isResubscribe = activeBeforePurchase.contains(productId)
                        if let transactionId = transaction?.transactionIdentifier, !isResubscribe {
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
    }
}
