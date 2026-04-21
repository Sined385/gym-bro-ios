//
//  ProfileWorkoutCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import SwiftUI

struct ProfileWorkoutCard: View {
    let workout: ProfileWorkout
    var onShare: (() -> Void)?

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

            // Exercises (compact)
            if !workout.exercises.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(workout.exercises.prefix(4).enumerated()), id: \.element.id) { index, exercise in
                        compactExerciseRow(exercise)

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

            // Share button
            if let onShare {
                Button {
                    onShare()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                        Text("Share")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.gymBroPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.gymBroPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
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

    private func compactExerciseRow(_ exercise: HistoryExercise) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: exercise.accentColor))
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
                    .lineLimit(1)

                if let muscleGroup = exercise.muscleGroup {
                    Text(muscleGroup.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.gymBroTextSecondary)
                }
            }

            Spacer(minLength: 4)

            Text(exerciseSummary(exercise))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func exerciseSummary(_ exercise: HistoryExercise) -> String {
        let sets = exercise.sets.count
        let totalReps = exercise.sets.reduce(0) { $0 + $1.reps }
        let maxWeight = exercise.sets.compactMap(\.weight).max()

        if let weight = maxWeight, weight > 0 {
            let unit = exercise.sets.first?.weightUnit ?? "kg"
            return "\(sets)×\(totalReps / max(sets, 1)) · \(weight.formattedWeight) \(unit)"
        }
        return "\(sets)×\(totalReps / max(sets, 1))"
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
