//
//  WorkoutLibraryView.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-02.
//

import SwiftUI

struct WorkoutLibraryView: View {
    @StateObject private var viewModel: WorkoutTemplatesViewModel = DependencyContainer.shared.resolve(WorkoutTemplatesViewModel.self)
    @StateObject private var exerciseVM: ExerciseLibraryViewModel = DependencyContainer.shared.resolve(ExerciseLibraryViewModel.self)
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @Environment(\.dismiss) private var dismiss

    private enum LibraryTab: String, CaseIterable {
        case workouts = "Workouts"
        case exercises = "Exercises"
    }

    @State private var selectedTab: LibraryTab = .workouts

    private let accentColors: [Color] = [
        Color(hex: "E86A75"), Color(hex: "30C08D"),
        Color(hex: "7A82F6"), Color(hex: "F5A623"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented picker
                Picker("", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                switch selectedTab {
                case .workouts:
                    workoutsTab
                case .exercises:
                    exercisesTab
                }
            }
            .background(Color.gymBroBackground.ignoresSafeArea())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.gymBroPrimary)
                }
            }
        }
        .task {
            await viewModel.loadTemplates()
        }
        .presentationDetents([.large])
        .sheet(isPresented: Binding(
            get: { viewModel.shareURL != nil },
            set: { if !$0 { viewModel.shareURL = nil } }
        )) {
            if let url = viewModel.shareURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }

    // MARK: - Workouts Tab

    private var workoutsTab: some View {
        Group {
            if viewModel.isLoading && viewModel.templates.isEmpty {
                ProgressView()
                    .tint(.gymBroPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.templates.isEmpty {
                emptyState
            } else {
                templateList
            }
        }
    }

    // MARK: - Exercises Tab

    private var exercisesTab: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gymBroNeutral400)

                TextField("Search exercises...", text: $exerciseVM.searchText)
                    .font(.system(size: 16))
                    .foregroundColor(.gymBroNeutral900)

                if !exerciseVM.searchText.isEmpty {
                    Button {
                        exerciseVM.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gymBroNeutral400)
                    }
                }
            }
            .padding(12)
            .background(Color.gymBroNeutral100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Muscle group filter
            MuscleGroupFilterChips(selectedGroup: $exerciseVM.selectedMuscleGroup)
                .padding(.top, 12)

            // Exercise list
            if exerciseVM.isLoading {
                Spacer()
                ProgressView()
                    .tint(.gymBroPrimary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(exerciseVM.filteredExercises) { item in
                            exerciseRow(item)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .task {
            if exerciseVM.exercises.isEmpty {
                await exerciseVM.loadExercises()
            }
        }
    }

    private func exerciseRow(_ item: ExerciseLibraryItem) -> some View {
        HStack(spacing: 12) {
            // Exercise image or fallback icon
            if let imageUrl = item.images?.first, let url = URL(string: imageUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ShimmerView()
                } failure: {
                    exercisePlaceholder
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                exercisePlaceholder
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)

                HStack(spacing: 8) {
                    Text(item.muscleGroup)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "2D3240").opacity(0.7))
                        .clipShape(Capsule())

                    Text(item.equipment)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroNeutral600)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.gymBroBackground)
    }

    private var exercisePlaceholder: some View {
        ZStack {
            Color(hex: "2D3240").opacity(0.08)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundColor(.gymBroNeutral400)
            Text("No saved workouts yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)
            Text("Save one from your workout screen")
                .font(.system(size: 15))
                .foregroundColor(.gymBroNeutral400)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Template List

    private var templateList: some View {
        List {
            ForEach(viewModel.templates) { template in
                templateCard(template)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let template = viewModel.templates[index]
                    Task { await viewModel.deleteTemplate(template.id) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Template Card

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(template.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Spacer()

                Button {
                    Task { await viewModel.shareTemplate(template) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gymBroNeutral400)
                        .frame(width: 36, height: 36)
                        .background(Color.gymBroNeutral100)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await viewModel.startFromTemplate(template)
                        dismiss()
                    }
                } label: {
                    Text("Start")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.gymBroPrimary, .gymBroPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Exercise count + exercise preview rows
            Text("\(template.exercises.count) exercises")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gymBroNeutral400)

            ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, exercise in
                PlanExerciseRow(
                    name: exercise.name,
                    muscleGroup: exercise.muscleGroup,
                    setsDisplay: exercise.setsDisplay,
                    accentColor: accentColors[index % accentColors.count],
                    imageUrl: exercise.imageUrl
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}
