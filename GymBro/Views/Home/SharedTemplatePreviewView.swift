//
//  SharedTemplatePreviewView.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-02.
//

import SwiftUI

struct SharedTemplatePreviewView: View {
    @StateObject private var viewModel: SharedTemplatePreviewViewModel
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var isFollowing = false

    private let accentColors: [Color] = [
        Color(hex: "E86A75"), Color(hex: "30C08D"),
        Color(hex: "7A82F6"), Color(hex: "F5A623"),
    ]

    init(shareCode: String) {
        _viewModel = StateObject(wrappedValue: SharedTemplatePreviewViewModel(
            shareCode: shareCode,
            networkService: DependencyContainer.shared.resolve(NetworkServiceProtocol.self),
            sessionManager: DependencyContainer.shared.resolve(ActiveSessionManager.self)
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gymBroBackground.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.gymBroPrimary)
                } else if let template = viewModel.template {
                    contentView(template)
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                }
            }
            .navigationTitle("Shared Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.gymBroPrimary)
                }
            }
        }
        .task {
            await viewModel.loadTemplate()
        }
        .presentationDetents([.large])
    }

    // MARK: - Content

    private func contentView(_ template: SharedTemplateResponse) -> some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Creator section
                    if let creator = template.creator {
                        creatorSection(creator)
                    }

                    // Workout name
                    Text(template.name)
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.gymBroNeutral900)
                        .padding(.horizontal, 20)

                    // Exercise count
                    Text("\(template.exercises.count) exercises")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gymBroNeutral400)
                        .padding(.horizontal, 20)

                    // Exercise list
                    VStack(spacing: 8) {
                        ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, exercise in
                            PlanExerciseRow(
                                name: exercise.name,
                                muscleGroup: exercise.muscleGroup,
                                setsDisplay: exercise.setsDisplay,
                                accentColor: accentColors[index % accentColors.count],
                                imageUrl: exercise.imageUrl,
                                showChevron: false
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }

            // Bottom buttons
            bottomButtons
        }
    }

    // MARK: - Creator Section

    private func creatorSection(_ creator: SharedTemplateCreator) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                AvatarView(
                    name: creator.name ?? "GymJam User",
                    avatarUrl: creator.avatarUrl,
                    size: 80
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "F5F5F5"), lineWidth: 3)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(creator.name ?? "GymJam User")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    if let username = creator.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                    }

                    if let goals = creator.primaryGoals, !goals.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gymBroPrimary)
                            Text(goals.map { formatGoal($0) }.joined(separator: ", "))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gymBroPrimary)
                        }
                    }

                    HStack(spacing: 4) {
                        if let level = creator.experienceLevel {
                            Text(level.capitalized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                        }
                        if creator.experienceLevel != nil && creator.bodyWeightKg != nil {
                            Text("•")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                        }
                        if let weight = creator.bodyWeightKg {
                            Text("\(Int(weight)) kg")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                        }
                    }
                }

                Spacer()
            }

            // Follower row + Follow button
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(creator.followerCount ?? 0)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    Text("Followers")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 32)

                VStack(spacing: 2) {
                    Text("\(creator.followingCount ?? 0)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    Text("Following")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 32)

                Button {
                    Task {
                        await viewModel.followCreator()
                        isFollowing = true
                    }
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isFollowing ? .gymBroNeutral400 : .white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(isFollowing ? Color.gymBroNeutral100 : Color.gymBroPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isFollowing)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
            .background(Color.gymBroCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
            )
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 20)
    }

    private func formatGoal(_ goal: String) -> String {
        goal.split(separator: ",")
            .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
            .joined(separator: ", ")
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 12) {
                // Save to Library
                Button {
                    Task {
                        await viewModel.saveToLibrary()
                        if viewModel.savedSuccessfully { dismiss() }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text(viewModel.savedSuccessfully ? "Saved!" : "Save to Library")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.gymBroPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gymBroPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving || viewModel.savedSuccessfully)

                // Start Workout
                Button {
                    Task {
                        await viewModel.startWorkout()
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Start Workout")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.gymBroPrimary, .gymBroPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(Color.white)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.gymBroNeutral400)
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
        }
    }
}
