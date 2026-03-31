//
//  PerformanceScoreCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-16.
//

import SwiftUI

// MARK: - PerformanceScoreCard

struct PerformanceScoreCard: View {

    // MARK: - Properties

    var score: Int?
    var trendDelta: Double? = -1.4

    // MARK: - Constants

    private let purpleAccent = Color(hex: "7A82F6")
    private let labelColor = Color(hex: "A1A1A1")
    private let mutedColor = Color(hex: "737373")
    private let trendRedColor = Color(hex: "E86A75")
    private let borderColor = Color.gymBroNeutral100

    var body: some View {
        HStack {
            // Left side
            VStack(alignment: .leading, spacing: 12) {
                // Icon + label row
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(purpleAccent.opacity(0.10))
                            .frame(width: 28, height: 28)

                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(purpleAccent)
                    }

                    Text("PERFORMANCE SCORE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundColor(labelColor)
                }

                // Score value
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(score ?? 0)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    Text("/100")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(mutedColor)
                }
            }

            Spacer()

            // Right side — trend indicator
            if let delta = trendDelta {
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: delta < 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(trendRedColor)

                    Text(String(format: "%+.1f", delta))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(trendRedColor)

                    Text("vs avg")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(mutedColor)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.03),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Preview

#Preview {
    PerformanceScoreCard(score: 87, trendDelta: -1.4)
        .padding(.horizontal, 20)
        .background(Color.gymBroBackground)
}
