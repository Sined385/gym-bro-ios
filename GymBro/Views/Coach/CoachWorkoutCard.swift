//
//  CoachWorkoutCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import SwiftUI

struct CoachWorkoutCard: View {
    let session: CoachSessionCard
    let onStartWorkout: () -> Void
    let onRegenerate: () -> Void

    @State private var selectedExercise: ExercisePreviewData?

    // MARK: - Constants

    private let borderColor = Color.gymBroNeutral100
    private let metadataColor = Color(hex: "737373")
    private let purpleAccent = Color(hex: "7A82F6")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            exerciseList
            startButton
            secondaryActions
        }
        .padding(24)
        .background(
            ZStack {
                Color.white

                LinearGradient(
                    colors: [
                        purpleAccent.opacity(0.05),
                        Color.clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.03),
            radius: 10,
            x: 0,
            y: 4
        )
        .sheet(item: $selectedExercise) { exercise in
            ExercisePreviewSheet(exercise: exercise)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title)
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.53)
                .foregroundColor(.gymBroNeutral900)

            HStack(spacing: 16) {
                if let duration = session.durationMinutes {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(duration) min")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(metadataColor)
                }

                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(session.exercises.count) exercises")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(metadataColor)
            }
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: 12) {
            ForEach(session.exercises) { exercise in
                Button {
                    selectedExercise = ExercisePreviewData(from: exercise)
                } label: {
                    ExerciseRowView(
                        name: localizedExerciseName(exercise.name, externalId: exercise.externalId),
                        sets: exercise.setsDisplay,
                        step: exercise.stepNumber,
                        accentColor: Color(hex: exercise.accentColor),
                        imageUrl: exercise.imageUrl
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button(action: onStartWorkout) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("Start Workout")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(purpleAccent)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(
                color: purpleAccent.opacity(0.25),
                radius: 10,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Secondary Actions

    private var secondaryActions: some View {
        HStack(spacing: 0) {
            Spacer()

            Button(action: onRegenerate) {
                Text("REGENERATE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(Color(hex: "A1A1A1"))
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    CoachWorkoutCard(
        session: CoachSessionCard(
            id: "1",
            title: "Quick DB Upper Body",
            type: "strength",
            durationMinutes: 30,
            exercises: [
                DashboardExercise(id: "1", name: "DB Bench Press", stepNumber: 1, setsDisplay: "3 \u{00D7} 10", accentColor: "#E86A75", libraryExerciseId: nil, muscleGroup: "Chest", equipment: "Dumbbells", suggestedWeight: nil, imageUrl: nil, externalId: nil),
                DashboardExercise(id: "2", name: "DB Rows", stepNumber: 2, setsDisplay: "3 \u{00D7} 10", accentColor: "#30C08D", libraryExerciseId: nil, muscleGroup: "Back", equipment: "Dumbbells", suggestedWeight: nil, imageUrl: nil, externalId: nil),
                DashboardExercise(id: "3", name: "DB Shoulder Press", stepNumber: 3, setsDisplay: "3 \u{00D7} 10", accentColor: "#7A82F6", libraryExerciseId: nil, muscleGroup: "Shoulders", equipment: "Dumbbells", suggestedWeight: nil, imageUrl: nil, externalId: nil),
                DashboardExercise(id: "4", name: "DB Curls", stepNumber: 4, setsDisplay: "3 \u{00D7} 12", accentColor: "#F5A623", libraryExerciseId: nil, muscleGroup: "Arms", equipment: "Dumbbells", suggestedWeight: nil, imageUrl: nil, externalId: nil),
            ]
        ),
        onStartWorkout: {},
        onRegenerate: {}
    )
    .padding(20)
}
