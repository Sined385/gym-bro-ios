//
//  CreateCustomWorkoutView.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-24.
//

import SwiftUI

struct CreateCustomWorkoutView: View {
    @StateObject private var viewModel: CreateCustomWorkoutViewModel = DependencyContainer.shared.resolve(CreateCustomWorkoutViewModel.self)
    @StateObject private var exerciseVM: ExerciseLibraryViewModel = DependencyContainer.shared.resolve(ExerciseLibraryViewModel.self)
    @Environment(\.dismiss) private var dismiss

    var onSaved: () -> Void

    private let accentColors: [String] = ["E86A75", "30C08D", "7A82F6", "F5A623"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Name field
                    HStack(spacing: 10) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)

                        TextField("Workout name", text: $viewModel.workoutName)
                            .font(.system(size: 16))
                            .foregroundColor(.gymBroNeutral900)
                    }
                    .padding(12)
                    .background(Color.gymBroNeutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Exercise list or empty state
                    if viewModel.selectedExercises.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.gymBroPrimary.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gymBroPrimary)
                            }
                            Text("Add Exercises")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.gymBroNeutral900)
                            Text("Tap + to build your workout")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gymBroNeutral400)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(Array(viewModel.selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                                    SwipeToDeleteCard {
                                        exerciseCardContent(exercise, index: index)
                                    } onDelete: {
                                        viewModel.removeExerciseById(exercise.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 120)
                        }
                    }
                }

                // Bottom bar
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Add Exercise button
                        Button {
                            viewModel.showExercisePicker = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.25))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 64, height: 64)
                            .background(
                                LinearGradient(
                                    colors: [.gymBroPrimary, .gymBroPrimaryDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.gymBroPrimary.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)

                        // Save button
                        Button {
                            Task {
                                if let _ = await viewModel.saveWorkout() {
                                    onSaved()
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                Text("Save Workout")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(viewModel.canSave ? Color(hex: "2D3240") : Color(hex: "2D3240").opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canSave || viewModel.isSaving)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color.gymBroBackground.ignoresSafeArea())
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gymBroNeutral400)
                }
            }
        }
        .sheet(isPresented: $viewModel.showExercisePicker) {
            NavigationStack {
                ExerciseLibraryView(
                    viewModel: exerciseVM,
                    addedExerciseIds: viewModel.selectedExerciseIds,
                    onExerciseSelected: { exercise in
                        viewModel.addExercise(exercise)
                    },
                    onStartSuperset: {},
                    onCreateCustom: {}
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            viewModel.showExercisePicker = false
                        }
                        .foregroundColor(.gymBroPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Exercise Card Content

    private func exerciseCardContent(_ exercise: ExerciseLibraryItem, index: Int) -> some View {
        let accentColor = accentColors[index % accentColors.count]
        let imageUrl = ExerciseImageURLBuilder.thumbnailURL(for: exercise.externalId)?.absoluteString

        return HStack(spacing: 16) {
            // Accent bar
            RoundedRectangle(cornerRadius: 100)
                .fill(Color(hex: accentColor))
                .frame(width: 6, height: 56)

            // Exercise image
            exerciseImage(imageUrl)

            VStack(alignment: .leading, spacing: 4) {
                Text(localizedExerciseName(exercise.name, externalId: exercise.externalId))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .lineLimit(1)
                    .tracking(-0.3)

                // Sets badge
                Text("3 \u{00D7} 10")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "737373"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(Color(hex: "F5F5F5"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 1)
        .frame(minHeight: 72)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private func exerciseImage(_ imageUrl: String?) -> some View {
        if let imageUrl, let url = URL(string: imageUrl) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                exercisePlaceholder
            } failure: {
                exercisePlaceholder
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            exercisePlaceholder
        }
    }

    private var exercisePlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(hex: "F5F5F5"))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "D4D4D4"))
            )
    }
}
