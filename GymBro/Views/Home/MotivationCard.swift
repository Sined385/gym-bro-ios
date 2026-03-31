//
//  MotivationCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-13.
//

import SwiftUI

struct MotivationCard: View {

    // MARK: - Properties

    var title: String?
    var message: String?

    // MARK: - Constants

    private let cardBackground = Color(hex: "2D3240")
    private let subtitleColor = Color(hex: "A1A1A1")

    private var displayTitle: String {
        title ?? "Great momentum! \u{1F525}"
    }

    private var displayMessage: String {
        message ?? "You've crushed 4 workouts this week and hit a new PR on squats. Keep building that consistency!"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 48, height: 48)

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(displayTitle)
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.89)
                    .foregroundColor(.white)

                Text(displayMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(subtitleColor)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(
            color: Color(hex: "2D3240").opacity(0.15),
            radius: 12.5,
            x: 0,
            y: 20
        )
    }
}

#Preview {
    MotivationCard()
        .padding(.horizontal, 20)
        .background(Color.gymBroBackground)
}
