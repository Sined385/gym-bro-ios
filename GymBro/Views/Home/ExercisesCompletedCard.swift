//
//  ExercisesCompletedCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-16.
//

import SwiftUI

// MARK: - ExercisesCompletedCard

struct ExercisesCompletedCard: View {

    // MARK: - Properties

    var exercises: [HistoryExercise]

    // MARK: - Constants

    private let labelColor = Color(hex: "A1A1A1")
    private let borderColor = Color.gymBroNeutral100

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("EXERCISES COMPLETED")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundColor(labelColor)
                .padding(.leading, 4)

            // Exercise rows with dividers
            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseHistoryRow(exercise: exercise)

                    // Divider between rows (not after last)
                    if index < exercises.count - 1 {
                        Divider()
                            .background(borderColor)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(16)
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
    let mockExercises: [HistoryExercise] = [
        HistoryExercise(
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
        ),
        HistoryExercise(
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
        ),
        HistoryExercise(
            id: "3",
            name: "Overhead Press",
            muscleGroup: "Shoulders",
            accentColor: "7A82F6",
            stepNumber: 3,
            sets: [
                ExerciseSetData(setNumber: 1, weight: 95, weightUnit: "lbs", reps: 10),
                ExerciseSetData(setNumber: 2, weight: 95, weightUnit: "lbs", reps: 10),
                ExerciseSetData(setNumber: 3, weight: 105, weightUnit: "lbs", reps: 8),
            ]
        ),
    ]

    ExercisesCompletedCard(exercises: mockExercises)
        .padding(.horizontal, 20)
        .background(Color.gymBroBackground)
}
