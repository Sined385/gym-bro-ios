//
//  FeatureShowcaseCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import SwiftUI

/// Reusable feature card for showcase onboarding screens
struct FeatureShowcaseCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Light gradient icon square
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gymBroPrimary.opacity(0.1),
                                Color.gymBroPrimaryDark.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.gymBroPrimary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .tracking(-0.89)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gymBroNeutral600)
                    .tracking(-0.15)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(21)
        .background(Color.white)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        FeatureShowcaseCard(
            icon: "chart.bar.fill",
            title: "Live Progress Tracking",
            subtitle: "See your gains in real-time with volume, PRs, and strength trends"
        )
        FeatureShowcaseCard(
            icon: "timer",
            title: "Smart Rest Timer",
            subtitle: "Automatically start rest timers between sets with custom durations"
        )
        FeatureShowcaseCard(
            icon: "bolt.fill",
            title: "Quick Start Workouts",
            subtitle: "Jump into your routine or start a custom session in seconds"
        )
    }
    .padding(24)
    .background(Color.gymBroBackground)
}
