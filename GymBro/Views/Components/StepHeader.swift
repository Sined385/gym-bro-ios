//
//  StepHeader.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI

/// Horizontal icon + title header for onboarding steps
struct StepHeader: View {
    let icon: String // SF Symbol name
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            // Gradient rounded square with icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gymBroPrimaryGradient)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.gymBroPrimary.opacity(0.3), radius: 8, x: 0, y: 8)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }

            // Title
            Text(title)
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.gymBroNeutral900)
                .tracking(-0.35)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 40) {
        StepHeader(
            icon: "target",
            title: "What is your primary goal?"
        )

        StepHeader(
            icon: "figure.run",
            title: "What is your primary sport?"
        )

        StepHeader(
            icon: "person.fill",
            title: "Tell us about yourself"
        )
    }
    .padding(24)
    .background(Color.gymBroBackground)
}
