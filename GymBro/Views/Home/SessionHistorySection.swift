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

    @State private var pendingShareData: CompletedWorkoutShareData?

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

            // Exercises completed
            ExercisesCompletedCard(exercises: session.exercises)

            // Share button — opens the share builder pre-loaded with this session.
            shareButton
        }
        .sheet(item: $pendingShareData) { data in
            ShareEditorView(
                data: data,
                onShare: { _ in pendingShareData = nil },
                onSkip: { pendingShareData = nil }
            )
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            pendingShareData = Self.shareData(from: session)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                Text("Share")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [.gymBroPrimary, .gymBroPrimaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Adapter

    /// Converts a SessionHistory (Home tab) into the same payload the
    /// post-completion editor consumes, so the builder works identically
    /// whether you just finished a workout or are re-sharing a past one.
    private static func shareData(from session: SessionHistory) -> CompletedWorkoutShareData {
        let activeExercises = session.exercises.map { he in
            ActiveSessionExercise(
                id: he.id,
                libraryExerciseId: nil,
                name: he.name,
                muscleGroup: he.muscleGroup ?? "Other",
                equipment: "",
                accentColor: he.accentColor,
                stepNumber: he.stepNumber,
                sets: he.sets.map { sd in
                    ActiveSet(
                        id: UUID().uuidString,
                        setNumber: sd.setNumber,
                        weight: sd.weight,
                        weightUnit: sd.weightUnit,
                        reps: sd.reps,
                        isCompleted: true,
                        isBodyweight: sd.isBodyweight
                    )
                },
                supersetGroupId: nil,
                supersetOrder: nil,
                targetSets: he.sets.count,
                targetReps: 0,
                imageUrl: he.imageUrl,
                externalId: he.externalId
            )
        }
        return CompletedWorkoutShareData(
            sessionId: session.id,
            sessionTitle: session.title,
            exercises: activeExercises,
            effortLevel: 0,
            energyLevel: 0,
            durationMinutes: session.durationMinutes,
            calories: session.calories,
            avgHeartRate: session.avgHeartRate
        )
    }
}

// MARK: - Preview

#Preview {
    let mockSession = SessionHistory(
        id: "session-1",
        sessionIds: ["session-1"],
        title: "Upper Body Strength",
        type: "strength",
        durationMinutes: 52,
        calories: 385,
        avgHeartRate: nil,
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
