//
//  PlanDayCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import SwiftUI

struct PlanDayCard: View {

    let day: PlanDayData
    let state: PlanDayState
    var onStartSession: () -> Void = {}
    var isStarting: Bool = false

    @State private var showGainsNotes: Bool = false
    @State private var selectedExercise: ExercisePreviewData?

    var body: some View {
        Group {
            switch state {
            case .completed:
                completedCard
            case .upNext:
                upNextCard
            case .future:
                futureCard
            case .rest:
                restCard
            case .skipped:
                skippedCard
            }
        }
    }

    // MARK: - Completed Card

    private var completedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.sessionTitle ?? "Training")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    if let groups = day.muscleGroups, !groups.isEmpty {
                        Text(groups.joined(separator: ", "))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "737373"))
                    }
                }

                Spacer()

                // Completed badge
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("COMPLETED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(Color(hex: "30C08D"))
            }

            // Duration info
            if let session = day.workoutSession, let duration = session.durationMinutes {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("\(duration) min")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color(hex: "737373"))
            }

            // Gains & Notes
            if let notes = day.aiNotes, !notes.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showGainsNotes.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("Gains & Notes")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: showGainsNotes ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "7A82F6"))
                }
                .buttonStyle(.plain)

                if showGainsNotes {
                    Text(notes)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "525252"))
                        .lineSpacing(3)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "F8F9FA"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }

    // MARK: - Up Next Card

    private var upNextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.sessionTitle ?? "Training")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    if let groups = day.muscleGroups, !groups.isEmpty {
                        Text(groups.joined(separator: ", "))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "737373"))
                    }
                }

                Spacer()

                // Up Next badge
                Text("UP NEXT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Color(hex: "E86A75"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "E86A75").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Exercise list
            if let exercises = day.exercises, !exercises.isEmpty {
                VStack(spacing: 8) {
                    ForEach(exercises) { exercise in
                        Button {
                            selectedExercise = ExercisePreviewData(from: exercise)
                        } label: {
                            PlanExerciseRow(
                                name: localizedExerciseName(exercise.name, externalId: exercise.externalId),
                                muscleGroup: exercise.muscleGroup,
                                setsDisplay: exercise.setsDisplay,
                                accentColor: Color(hex: exercise.accentColor ?? "E86A75"),
                                imageUrl: exercise.imageUrl
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Start Session button
            Button(action: onStartSession) {
                HStack(spacing: 8) {
                    if isStarting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text("Start Session")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.gymBroNeutral900)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(isStarting)
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(hex: "E86A75").opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color(hex: "E86A75").opacity(0.08), radius: 12, x: 0, y: 4)
        .sheet(item: $selectedExercise) { exercise in
            ExercisePreviewSheet(exercise: exercise)
        }
    }

    // MARK: - Future Card

    private var futureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.sessionTitle ?? "Training")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    if let groups = day.muscleGroups, !groups.isEmpty {
                        Text(groups.joined(separator: ", "))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "737373"))
                    }
                }

                Spacer()
            }

            // Exercise list
            if let exercises = day.exercises, !exercises.isEmpty {
                VStack(spacing: 8) {
                    ForEach(exercises) { exercise in
                        Button {
                            selectedExercise = ExercisePreviewData(from: exercise)
                        } label: {
                            PlanExerciseRow(
                                name: localizedExerciseName(exercise.name, externalId: exercise.externalId),
                                muscleGroup: exercise.muscleGroup,
                                setsDisplay: exercise.setsDisplay,
                                accentColor: Color(hex: exercise.accentColor ?? "E86A75"),
                                imageUrl: exercise.imageUrl
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .opacity(0.85)
        .sheet(item: $selectedExercise) { exercise in
            ExercisePreviewSheet(exercise: exercise)
        }
    }

    // MARK: - Rest Card

    private var restCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "A1A1A1"))

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest Day")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
                Text("Recovery & regeneration")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "A1A1A1"))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .opacity(0.7)
    }

    // MARK: - Skipped Card

    private var skippedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.forward")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "A1A1A1"))

            VStack(alignment: .leading, spacing: 2) {
                Text(day.sessionTitle ?? "Training")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
                    .strikethrough(true, color: Color(hex: "A1A1A1"))
                Text("Redistributed to later this week")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "A1A1A1"))
            }

            Spacer()

            Text("SKIPPED")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundColor(Color(hex: "A1A1A1"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "A1A1A1").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .opacity(0.7)
    }
}

#Preview {
    let mockDay = PlanDayData(
        id: "test",
        dayOfWeek: 0,
        dayLabel: "Mon",
        dayType: "training",
        status: "pending",
        sessionTitle: "Upper Body Power",
        sessionType: "strength",
        muscleGroups: ["Chest", "Back"],
        exercises: [
            PlanExercise(name: "Bench Press", muscleGroup: "Chest", setsDisplay: "4 \u{00D7} 8", libraryExerciseId: nil, accentColor: "#E86A75"),
            PlanExercise(name: "Barbell Row", muscleGroup: "Back", setsDisplay: "4 \u{00D7} 8", libraryExerciseId: nil, accentColor: "#30C08D"),
        ],
        workoutSession: nil,
        aiNotes: nil
    )

    ScrollView {
        VStack(spacing: 16) {
            PlanDayCard(day: mockDay, state: .upNext)
        }
        .padding()
    }
    .background(Color.gymBroBackground)
}
