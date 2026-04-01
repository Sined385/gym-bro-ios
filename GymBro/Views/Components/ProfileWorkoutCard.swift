//
//  ProfileWorkoutCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import SwiftUI

struct ProfileWorkoutCard: View {
    let workout: ProfileWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.gymBroPrimary, Color.gymBroPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let duration = workout.durationMinutes {
                            Text("\(duration) MIN")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gymBroTextSecondary)
                        }
                        if workout.durationMinutes != nil && workout.calories != nil {
                            Text("\u{2022}")
                                .font(.system(size: 11))
                                .foregroundColor(.gymBroTextSecondary)
                        }
                        if let cal = workout.calories {
                            Text("\(cal) KCAL")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gymBroTextSecondary)
                        }
                    }
                }

                Spacer()
            }

            // Date
            Text(timeAgo(from: workout.completedAt))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)

            // Exercises with weights
            if !workout.exercises.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(workout.exercises.prefix(4).enumerated()), id: \.element.id) { index, exercise in
                        ExerciseHistoryRow(exercise: exercise)

                        if index < min(workout.exercises.count, 4) - 1 {
                            Divider()
                                .background(Color.gymBroNeutral100)
                                .padding(.vertical, 4)
                        }
                    }

                    if workout.exercises.count > 4 {
                        Text("+\(workout.exercises.count - 4) more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(Color.gymBroCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func timeAgo(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 604800 { return "\(seconds / 86400)d ago" }

        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}
