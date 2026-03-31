//
//  QuickWorkoutCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-13.
//

import SwiftUI

// MARK: - Fallback Exercise Model

private struct MockExercise: Identifiable {
    let id = UUID()
    let name: String
    let sets: String
    let accentColor: Color
    let step: Int
}

// MARK: - QuickWorkoutCard

struct QuickWorkoutCard: View {

    // MARK: - Properties

    var session: DashboardSession?
    var onStart: () -> Void = {}
    var isStarting: Bool = false

    @State private var selectedExercise: ExercisePreviewData?

    // MARK: - Constants

    private let borderColor = Color.gymBroNeutral100
    private let metadataColor = Color(hex: "737373")
    private let quoteBackground = Color(hex: "F8F9FA")
    private let quoteBorder = Color.gymBroNeutral100
    private let purpleAccent = Color(hex: "7A82F6")

    // MARK: - Fallback Data

    private static let fallbackExercises: [MockExercise] = [
        MockExercise(name: "Cat-Cow Stretches", sets: "2 \u{00D7} 10", accentColor: Color(hex: "E86A75"), step: 1),
        MockExercise(name: "Thoracic Rotations", sets: "2 \u{00D7} 8/side", accentColor: Color(hex: "30C08D"), step: 2),
        MockExercise(name: "Hip Flexor Stretch", sets: "2 \u{00D7} 30s/side", accentColor: Color(hex: "7A82F6"), step: 3),
        MockExercise(name: "90/90 Stretches", sets: "2 \u{00D7} 10/side", accentColor: Color(hex: "F5A623"), step: 4),
    ]

    // MARK: - Computed

    private var sessionTitle: String {
        session?.title ?? "Active Recovery"
    }

    private var sessionDuration: String {
        if let mins = session?.durationMinutes {
            return "\(mins) min"
        }
        return "25 min"
    }

    private var sessionExerciseCount: Int {
        session?.exercises.count ?? Self.fallbackExercises.count
    }

    private var aiQuote: String {
        session?.aiMessage ?? "Since you don't have a plan today, I generated a light mobility session to keep you moving and aid recovery."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            aiQuoteSection
            exerciseList
            startButton
        }
        .padding(24)
        .background(
            ZStack {
                Color.white

                // Subtle purple gradient overlay from top-left
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
            Text(sessionTitle)
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.53)
                .foregroundColor(.gymBroNeutral900)

            HStack(spacing: 16) {
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                    Text(sessionDuration)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(metadataColor)

                // Movements
                HStack(spacing: 4) {
                    Image(systemName: "figure.cooldown")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(sessionExerciseCount) movements")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(metadataColor)
            }
        }
    }

    // MARK: - AI Quote

    private var aiQuoteSection: some View {
        Text(aiQuote)
            .font(.system(size: 14, weight: .medium))
            .italic()
            .tracking(-0.15)
            .foregroundColor(metadataColor)
            .lineSpacing(3)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(quoteBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(quoteBorder, lineWidth: 1)
            )
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: 12) {
            if let exercises = session?.exercises {
                ForEach(exercises) { exercise in
                    Button {
                        selectedExercise = ExercisePreviewData(from: exercise)
                    } label: {
                        ExerciseRowView(
                            name: exercise.name,
                            sets: exercise.setsDisplay,
                            step: exercise.stepNumber,
                            accentColor: Color(hex: exercise.accentColor)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(Self.fallbackExercises) { exercise in
                    ExerciseRowView(
                        name: exercise.name,
                        sets: exercise.sets,
                        step: exercise.step,
                        accentColor: exercise.accentColor
                    )
                }
            }
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
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

                Text("Start")
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
}

#Preview {
    QuickWorkoutCard(session: nil)
        .padding(.horizontal, 20)
        .background(Color.gymBroBackground)
}
