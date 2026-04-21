//
//  PaywallView.swift
//  GymBro
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductIndex: Int = 2 // Default to annual

    private let analyticsService: AnalyticsTrackingServiceProtocol = {
        DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)
    }()

    var body: some View {
        ZStack {
            Color.gymBroBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection
                    featuresSection
                    planSelector
                    ctaButton
                    restoreButton
                    termsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topLeading) {
            closeButton
        }
        .task {
            await subscriptionManager.loadProducts()
            analyticsService.track("paywall_opened", properties: ["source": "general"])
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            analyticsService.track("paywall_dismissed", properties: [:])
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 38, height: 38)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)

                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
            }
        }
        .padding(.leading, 20)
        .padding(.top, 8)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gymBroPrimary, Color.gymBroPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .padding(.top, 40)

            Text("Unlock GymJam Premium")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.gymBroNeutral900)
                .multilineTextAlignment(.center)

            Text("Take your training to the next level")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureRow(icon: "bubble.left.and.text.bubble.right.fill", text: "Unlimited AI Coach conversations")
            featureRow(icon: "dumbbell.fill", text: "Custom exercises")
            featureRow(icon: "square.stack.3d.up.fill", text: "Supersets")
            featureRow(icon: "calendar.badge.plus", text: "AI training plan generation")
        }
        .padding(20)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "30C08D"))

            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gymBroNeutral900)

            Spacer()
        }
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        VStack(spacing: 12) {
            ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                let index = subscriptionManager.availableProducts.firstIndex(where: { $0.id == product.id }) ?? 0
                planCard(product: product, isSelected: selectedProductIndex == index)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProductIndex = index
                        }
                    }
            }
        }
    }

    private func planLabel(for product: Product) -> String {
        switch product.id {
        case SubscriptionManager.annualProductId: return "Annual"
        case SubscriptionManager.threeMonthProductId: return "3 Months"
        case SubscriptionManager.monthlyProductId: return "Monthly"
        default: return product.displayName
        }
    }

    private func planPeriod(for product: Product) -> String {
        switch product.id {
        case SubscriptionManager.annualProductId: return "/year"
        case SubscriptionManager.threeMonthProductId: return "/3 months"
        case SubscriptionManager.monthlyProductId: return "/month"
        default: return ""
        }
    }

    private func planCard(product: Product, isSelected: Bool) -> some View {
        let isAnnual = product.id == SubscriptionManager.annualProductId

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(planLabel(for: product))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    if isAnnual {
                        Text("Best Value")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "30C08D"))
                            .cornerRadius(6)
                    }
                }

                Text(product.displayPrice + planPeriod(for: product))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gymBroTextSecondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(isSelected ? Color.gymBroPrimary : Color(hex: "D4D4D4"), lineWidth: 2)
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .fill(Color.gymBroPrimary)
                        .frame(width: 14, height: 14)
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.gymBroPrimary : Color(hex: "F5F5F5"), lineWidth: isSelected ? 2 : 1)
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            guard !subscriptionManager.availableProducts.isEmpty else { return }
            let productIndex = min(selectedProductIndex, subscriptionManager.availableProducts.count - 1)
            let product = subscriptionManager.availableProducts[productIndex]
            Task {
                await subscriptionManager.purchase(product)
            }
        } label: {
            Group {
                if subscriptionManager.purchaseInProgress {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.gymBroPrimaryGradient)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(subscriptionManager.purchaseInProgress || subscriptionManager.availableProducts.isEmpty)
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await subscriptionManager.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
        }
    }

    // MARK: - Terms

    private var termsSection: some View {
        Text("Subscriptions auto-renew. Cancel anytime in Settings.")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(hex: "A1A1A1"))
            .multilineTextAlignment(.center)
    }
}
