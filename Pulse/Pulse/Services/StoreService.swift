//
//  StoreService.swift
//  Pulse
//

import StoreKit

@MainActor
@Observable
final class StoreService {
    static let shared = StoreService()

    private static let productID = "com.jpcostan.Pulse.pro.lifetime"

    private(set) var isPro = false
    private(set) var product: Product?
    private(set) var purchaseError: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updateEntitlements()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            NSLog("StoreService: Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else {
            purchaseError = "Product not available. Please try again later."
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPro = true
                purchaseError = nil
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            NSLog("StoreService: Purchase error: \(error)")
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        await updateEntitlements()
        if !isPro {
            purchaseError = "No previous purchase found."
        }
    }

    // MARK: - Entitlements

    func updateEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                isPro = true
                return
            }
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        let productID = Self.productID
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    if transaction.productID == productID && transaction.revocationDate == nil {
                        await MainActor.run { [weak self] in
                            self?.isPro = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Verification

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
