//
//  SessionStatsRow.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-16.
//

import SwiftUI

// MARK: - SessionStatsRow

struct SessionStatsRow: View {

    // MARK: - Properties

    var durationMinutes: Int?
    var calories: Int?

    // MARK: - Constants

    private let pinkAccent = Color(hex: "E86A75")
    private let greenAccent = Color(hex: "30C08D")
    private let labelColor = Color(hex: "A1A1A1")
    private let borderColor = Color.gymBroNeutral100

    var body: some View {
        HStack(spacing: 12) {
            durationCard
            caloriesCard
        }
    }

    // MARK: - Duration Card

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // Pink tinted circle with clock icon
                ZStack {
                    Circle()
                        .fill(pinkAccent.opacity(0.10))
                        .frame(width: 28, height: 28)

                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(pinkAccent)
                }

                Text("DURATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(labelColor)
            }

            // Large value
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(durationMinutes ?? 0)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Text("min")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gymBroNeutral900)
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

    // MARK: - Calories Card

    private var caloriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // Green tinted circle with flame icon
                ZStack {
                    Circle()
                        .fill(greenAccent.opacity(0.10))
                        .frame(width: 28, height: 28)

                    Image(systemName: "flame")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(greenAccent)
                }

                Text("CALORIES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(labelColor)
            }

            // Large value
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(calories ?? 0)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Text("kcal")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gymBroNeutral900)
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
    SessionStatsRow(durationMinutes: 52, calories: 385)
        .padding(.horizontal, 20)
        .background(Color.gymBroBackground)
}
