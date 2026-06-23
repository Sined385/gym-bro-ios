//
//  ExerciseHistoryRow.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-16.
//

import SwiftUI

// MARK: - ExerciseHistoryRow

struct ExerciseHistoryRow: View {

    // MARK: - Properties

    var exercise: HistoryExercise

    // MARK: - Constants

    private let labelColor = Color(hex: "A1A1A1")
    private let mutedColor = Color(hex: "737373")
    private let borderColor = Color.gymBroNeutral100

    // MARK: - Computed

    private var totalSets: Int {
        exercise.sets.count
    }

    private var totalReps: Int {
        exercise.sets.reduce(0) { $0 + $1.reps }
    }

    /// Cardio is duration-based — show time + distance, not "1 sets / 0 reps".
    private var isCardio: Bool {
        exercise.muscleGroup?.caseInsensitiveCompare("Cardio") == .orderedSame
            || exercise.sets.contains { $0.durationSeconds != nil }
    }

    private var totalDurationSeconds: Int {
        exercise.sets.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
    }

    private var totalDistanceMeters: Int {
        exercise.sets.reduce(0) { $0 + ($1.distanceMeters ?? 0) }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    private func formatDistance(_ meters: Int) -> String {
        let km = Double(meters) / 1000.0
        return String(format: km >= 10 ? "%.1f km" : "%.2f km", km)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            // Cardio is a single duration block — the header already shows
            // time + distance, so the per-set chip row is redundant.
            if !isCardio {
                setsScrollView
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 14) {
            // Colored accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: exercise.accentColor))
                .frame(width: 6, height: 28)

            // Exercise name + muscle group
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                if let muscleGroup = exercise.muscleGroup {
                    Text(muscleGroup.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundColor(labelColor)
                }
            }

            Spacer()

            // Summary — cardio shows time + distance, strength shows sets/reps.
            VStack(alignment: .trailing, spacing: 2) {
                if isCardio {
                    Text(formatDuration(totalDurationSeconds))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    Text(totalDistanceMeters > 0 ? formatDistance(totalDistanceMeters) : "—")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(mutedColor)
                } else {
                    Text("\(totalSets) sets")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    Text("\(totalReps) reps")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(mutedColor)
                }
            }
        }
    }

    // MARK: - Sets Scroll View

    private var setsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(exercise.sets) { setData in
                    setChip(setData)
                }
            }
        }
    }

    // MARK: - Set Chip

    @ViewBuilder
    private func setChip(_ setData: ExerciseSetData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SET \(setData.setNumber)")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundColor(labelColor)

            if isCardio {
                Text(formatDuration(setData.durationSeconds ?? 0))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                Text((setData.distanceMeters ?? 0) > 0 ? formatDistance(setData.distanceMeters ?? 0) : "—")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
            } else {
                Text(SetDisplay.weightChunk(
                    weight: setData.weight,
                    weightUnit: setData.weightUnit,
                    isBodyweight: setData.isBodyweight
                ))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(setData.isBodyweight ? .gymBroPrimary : .gymBroNeutral900)

                Text("\(setData.reps) reps")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
            }
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    let mockExercise = HistoryExercise(
        id: "1",
        name: "Bench Press",
        muscleGroup: "Chest",
        accentColor: "E86A75",
        stepNumber: 1,
        sets: [
            ExerciseSetData(setNumber: 1, weight: 185, weightUnit: "lbs", reps: 8),
            ExerciseSetData(setNumber: 2, weight: 185, weightUnit: "lbs", reps: 8),
            ExerciseSetData(setNumber: 3, weight: 195, weightUnit: "lbs", reps: 6),
            ExerciseSetData(setNumber: 4, weight: 195, weightUnit: "lbs", reps: 7),
        ]
    )

    let bodyweightExercise = HistoryExercise(
        id: "2",
        name: "Pull-ups",
        muscleGroup: "Back",
        accentColor: "30C08D",
        stepNumber: 2,
        sets: [
            ExerciseSetData(setNumber: 1, weight: nil, weightUnit: "lbs", reps: 12),
            ExerciseSetData(setNumber: 2, weight: nil, weightUnit: "lbs", reps: 10),
            ExerciseSetData(setNumber: 3, weight: nil, weightUnit: "lbs", reps: 8),
        ]
    )

    VStack(spacing: 20) {
        ExerciseHistoryRow(exercise: mockExercise)
        ExerciseHistoryRow(exercise: bodyweightExercise)
    }
    .padding(.horizontal, 20)
    .background(Color.gymBroBackground)
}
