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
    /// Fixed width for horizontal scrolls (default 300). Pass nil to let the
    /// card stretch to fill its parent — used by the vertical workouts list.
    var cardWidth: CGFloat? = 300

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

            // Date — explicit calendar date, not "X days ago"
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                Text(formattedDate(workout.completedAt))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.gymBroTextSecondary)

            // Exercises — all of them, with every set listed.
            if !workout.exercises.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                        expandedExerciseRow(exercise)

                        if index < workout.exercises.count - 1 {
                            Divider()
                                .background(Color.gymBroNeutral100)
                        }
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
        .frame(width: cardWidth, alignment: .leading)
        .frame(maxWidth: cardWidth == nil ? .infinity : nil, alignment: .leading)
        .background(Color.gymBroCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func expandedExerciseRow(_ exercise: HistoryExercise) -> some View {
        // Content VStack first; the accent bar is added as a leading overlay
        // so it sizes itself to the row's intrinsic height. No greedy
        // .frame(maxHeight: .infinity) — that was making every row stretch
        // to fill the card and leaving huge empty space below the last set.
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let muscleGroup = exercise.muscleGroup {
                    Text(muscleGroup.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.gymBroTextSecondary)
                }
            }

            if !exercise.sets.isEmpty {
                VStack(spacing: 3) {
                    ForEach(exercise.sets) { set in
                        HStack(spacing: 0) {
                            Text("Set \(set.setNumber)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                                .frame(width: 44, alignment: .leading)

                            Text(setDisplay(set))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gymBroNeutral900)

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(.leading, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: exercise.accentColor))
                .frame(width: 4)
        }
    }

    private func setDisplay(_ set: ExerciseSetData) -> String {
        if set.isBodyweight {
            return "BW × \(set.reps)"
        }
        if let weight = set.weight, weight > 0 {
            return "\(weight.formattedWeight) \(set.weightUnit) × \(set.reps)"
        }
        return "× \(set.reps)"
    }

    private func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString)
        guard let date else { return isoString }
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return df.string(from: date)
    }
}
