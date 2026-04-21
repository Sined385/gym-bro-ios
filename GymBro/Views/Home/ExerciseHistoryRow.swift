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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            setsScrollView
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

            // Sets + reps summary
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(totalSets) sets")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Text("\(totalReps) reps")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(mutedColor)
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

            if let weight = setData.weight {
                Text("\(weight.formattedWeight) \(setData.weightUnit)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
            }

            Text("\(setData.reps) reps")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.gymBroNeutral900)
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
