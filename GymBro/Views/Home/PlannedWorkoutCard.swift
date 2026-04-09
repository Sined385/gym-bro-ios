//
//  PlannedWorkoutCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import SwiftUI

struct PlannedWorkoutCard: View {

    // MARK: - Properties

    var plannedWorkout: PlannedWorkoutResponse
    var onStart: () -> Void = {}
    var isStarting: Bool = false

    @State private var selectedExercise: ExercisePreviewData?

    // MARK: - Constants

    private let borderColor = Color.gymBroNeutral100
    private let metadataColor = Color(hex: "737373")
    private let purpleAccent = Color(hex: "7A82F6")

    // MARK: - Computed

    private var sessionTitle: String {
        plannedWorkout.sessionTitle ?? "Training Session"
    }

    private var muscleGroupsText: String {
        plannedWorkout.muscleGroups?.joined(separator: ", ") ?? ""
    }

    private var exerciseCount: Int {
        plannedWorkout.exercises?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Planned Workout")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.44)
                .foregroundColor(.gymBroNeutral900)

            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(sessionTitle)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.53)
                        .foregroundColor(.gymBroNeutral900)

                    HStack(spacing: 16) {
                        if !muscleGroupsText.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(muscleGroupsText)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(metadataColor)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "figure.cooldown")
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(exerciseCount) exercises")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(metadataColor)
                    }
                }

                // Exercise list
                if let exercises = plannedWorkout.exercises {
                    VStack(spacing: 12) {
                        ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                            Button {
                                selectedExercise = ExercisePreviewData(
                                    name: exercise.name,
                                    muscleGroup: exercise.muscleGroup,
                                    setsDisplay: exercise.setsDisplay,
                                    accentColor: exercise.accentColor,
                                    suggestedWeight: exercise.suggestedWeight,
                                    externalId: exercise.externalId
                                )
                            } label: {
                                ExerciseRowView(
                                    name: exercise.name,
                                    sets: exercise.setsDisplay,
                                    step: index + 1,
                                    accentColor: Color(hex: exercise.accentColor),
                                    imageUrl: exercise.imageUrl
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Start button
                Button(action: onStart) {
                    HStack(spacing: 8) {
                        if isStarting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Start Session")
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
                .disabled(isStarting)
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
        }
        .sheet(item: $selectedExercise) { exercise in
            ExercisePreviewSheet(exercise: exercise)
        }
    }
}

#Preview {
    PlannedWorkoutCard(
        plannedWorkout: PlannedWorkoutResponse(
            type: "training",
            planDayId: "test",
            sessionTitle: "Upper Body Power",
            sessionType: "strength",
            muscleGroups: ["Chest", "Back"],
            status: "pending",
            exercises: [
                PlannedExercise(name: "Bench Press", muscleGroup: "Chest", setsDisplay: "4 \u{00D7} 8", libraryExerciseId: nil, accentColor: "#E86A75", suggestedWeight: 185, imageUrl: nil, externalId: nil),
                PlannedExercise(name: "Pull-ups", muscleGroup: "Back", setsDisplay: "3 \u{00D7} 10", libraryExerciseId: nil, accentColor: "#30C08D", suggestedWeight: nil, imageUrl: nil, externalId: nil),
            ]
        )
    )
    .padding(.horizontal, 20)
    .background(Color.gymBroBackground)
}
