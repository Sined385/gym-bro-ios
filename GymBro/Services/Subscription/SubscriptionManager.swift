//
//  SubscriptionManager.swift
//  GymBro
//

import Foundation
import Combine
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Published Properties

    @Published var isPremium: Bool = false
    @Published var coachMessagesUsed: Int = 0
    @Published var coachMessagesLimit: Int = 20
    @Published var availableProducts: [Product] = []
    @Published var purchaseInProgress: Bool = false
    @Published var showPaywall: Bool = false

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let analyticsService: AnalyticsTrackingServiceProtocol
    private var transactionListener: Task<Void, Never>?

    // MARK: - Product IDs

    static let monthlyProductId = "com.gymjam.monthly.subscription"
    static let threeMonthProductId = "com.gymgam.threemonth.subscription"
    static let annualProductId = "com.gymjam.annual.subscription"
    static let allProductIds: Set<String> = [monthlyProductId, threeMonthProductId, annualProductId]

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, analyticsService: AnalyticsTrackingServiceProtocol) {
        self.networkService = networkService
        self.analyticsService = analyticsService
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Status from API

    func loadStatus() async {
        // Sync entitlement status with backend first
        await syncEntitlementWithBackend()

        do {
            let status = try await networkService.request(
                SubscriptionRouter.getStatus.endpoint,
                responseType: SubscriptionStatusResponse.self
            )
            isPremium = status.isPremium
            coachMessagesUsed = status.coachMessagesUsed
            coachMessagesLimit = status.coachMessagesLimit ?? 20
        } catch {
            print("[SubscriptionManager] Failed to load status: \(error)")
        }
    }

    // MARK: - Sync Entitlement with Backend

    private func syncEntitlementWithBackend() async {
        var activeTransactionId: String?
        var activeProductId: String?
        var hasActive = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                hasActive = true
                activeTransactionId = String(transaction.id)
                activeProductId = transaction.productID
                break
            }
        }

        do {
            let response = try await networkService.request(
                SubscriptionRouter.sync(
                    hasActiveEntitlement: hasActive,
                    transactionId: activeTransactionId,
                    productId: activeProductId
                ).endpoint,
                responseType: SyncResponse.self
            )
            isPremium = response.isPremium
        } catch {
            print("[SubscriptionManager] Sync failed: \(error)")
        }
    }

    // MARK: - Load StoreKit Products

    func loadProducts() async {
        do {
            print("[SubscriptionManager] Loading products for IDs: \(Self.allProductIds)")
            let products = try await Product.products(for: Self.allProductIds)
            print("[SubscriptionManager] Loaded \(products.count) products: \(products.map { "\($0.id) - \($0.displayPrice)" })")
            availableProducts = products.sorted { $0.price < $1.price }
        } catch {
            print("[SubscriptionManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseInProgress = true
        analyticsService.track("paywall_purchase_tapped", properties: ["product_id": product.id])

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await verifyWithBackend(transactionId: String(transaction.id), productId: product.id)
                await transaction.finish()
                analyticsService.track("paywall_purchase_completed", properties: ["product_id": product.id])

            case .userCancelled:
                break

            case .pending:
                break

            @unknown default:
                break
            }
        } catch {
            print("[SubscriptionManager] Purchase failed: \(error)")
        }

        purchaseInProgress = false
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        analyticsService.track("paywall_restore_tapped", properties: [:])

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                await verifyWithBackend(
                    transactionId: String(transaction.id),
                    productId: transaction.productID
                )
                await transaction.finish()
            }
        }

        await loadStatus()
    }

    // MARK: - Feature Access

    func canUseFeature(_ feature: PremiumFeature) -> Bool {
        if isPremium { return true }
        if feature == .coachChat {
            return coachMessagesUsed < coachMessagesLimit
        }
        return false
    }

    /// Returns true if the user can use the feature; if not, opens the paywall and returns false.
    func requireFeature(_ feature: PremiumFeature) -> Bool {
        if canUseFeature(feature) { return true }
        showPaywall = true
        return false
    }

    // MARK: - Private Helpers

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.notAvailableInStorefront
        case .verified(let safe):
            return safe
        }
    }

    private func verifyWithBackend(transactionId: String, productId: String) async {
        do {
            let _ = try await networkService.request(
                SubscriptionRouter.verify(transactionId: transactionId, productId: productId).endpoint,
                responseType: [String: Bool].self
            )
            isPremium = true
            showPaywall = false
        } catch {
            print("[SubscriptionManager] Backend verification failed: \(error)")
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await self?.verifyWithBackend(
                        transactionId: String(transaction.id),
                        productId: transaction.productID
                    )
                    await transaction.finish()
                }
            }
        }
    }
}
