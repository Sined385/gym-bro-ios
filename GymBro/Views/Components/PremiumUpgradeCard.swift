//
//  PremiumUpgradeCard.swift
//  GymBro
//

import SwiftUI

struct PremiumUpgradeCard: View {
    let description: String
    let subscriptionManager: SubscriptionManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gymBroPrimary)

                Text("Premium Feature")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Spacer()
            }

            Text(description)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                subscriptionManager.showPaywall = true
            } label: {
                Text("Upgrade to Premium")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.gymBroPrimaryGradient)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gymBroPrimary.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
