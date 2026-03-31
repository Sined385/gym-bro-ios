//
//  SessionHistorySection.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-16.
//

import SwiftUI

// MARK: - SessionHistorySection

struct SessionHistorySection: View {

    // MARK: - Properties

    var session: SessionHistory
    var dayLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("\(dayLabel)'s Session")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.44)
                .foregroundColor(.gymBroNeutral900)

            // Stats row (Duration + Calories)
            SessionStatsRow(
                durationMinutes: session.durationMinutes,
                calories: session.calories
            )

            // Performance score
            PerformanceScoreCard(score: session.performanceScore)

            // Exercises completed
            ExercisesCompletedCard(exercises: session.exercises)
        }
    }
}

// MARK: - Preview

#Preview {
    let mockSession = SessionHistory(
        id: "session-1",
        title: "Upper Body Strength",
        type: "strength",
        durationMinutes: 52,
        calories: 385,
        performanceScore: 87,
        exercises: [
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
            HistoryExercise(
                id: "4",
                name: "Dumbbell Rows",
                muscleGroup: "Back",
                accentColor: "F5A623",
                stepNumber: 4,
                sets: [
                    ExerciseSetData(setNumber: 1, weight: 60, weightUnit: "lbs", reps: 10),
                    ExerciseSetData(setNumber: 2, weight: 60, weightUnit: "lbs", reps: 10),
                    ExerciseSetData(setNumber: 3, weight: 65, weightUnit: "lbs", reps: 9),
                ]
            ),
        ]
    )

    ScrollView {
        SessionHistorySection(session: mockSession, dayLabel: "Mon")
            .padding(.horizontal, 20)
    }
    .background(Color.gymBroBackground)
}
