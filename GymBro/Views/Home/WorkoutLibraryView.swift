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
    @EnvironmentObject var favoritesService: FavoritesService
    @Environment(\.dismiss) private var dismiss

    private enum LibraryTab: String, CaseIterable {
        case workouts = "Workouts"
        case exercises = "Exercises"
    }

    @State private var selectedTab: LibraryTab = .workouts
    @State private var showCreateWorkout = false

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
        .sheet(isPresented: $showCreateWorkout) {
            CreateCustomWorkoutView(onSaved: {
                Task { await viewModel.loadTemplates() }
            })
        }
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
        VStack(spacing: 0) {
            // Create Custom Workout button
            Button {
                showCreateWorkout = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.gymBroPrimary)

                    Text("Create Custom Workout")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymBroPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gymBroNeutral400)
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)

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

            // Filters — two rows to match the in-workout picker.
            MuscleGroupFilterChips(selectedGroup: $exerciseVM.selectedMuscleGroup)
                .padding(.top, 12)

            EquipmentFilterChips(selectedEquipment: $exerciseVM.selectedEquipment)
                .padding(.top, 8)

            // Exercise list
            if exerciseVM.isLoading {
                Spacer()
                ProgressView()
                    .tint(.gymBroPrimary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(exerciseVM.filteredExercises(favoriteIds: favoritesService.favoriteIds)) { item in
                            NavigationLink {
                                ExerciseBrowseDetailView(item: item)
                            } label: {
                                exerciseCard(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
        }
        .task {
            if exerciseVM.exercises.isEmpty {
                await exerciseVM.loadExercises()
            }
        }
    }

    private func exerciseImageURLs(for item: ExerciseLibraryItem) -> [URL] {
        let builderURLs = ExerciseImageURLBuilder.imageURLs(for: item.externalId)
        if !builderURLs.isEmpty { return builderURLs }
        return item.images?.compactMap { URL(string: $0) } ?? []
    }

    private func exerciseCard(_ item: ExerciseLibraryItem) -> some View {
        let urls = exerciseImageURLs(for: item)

        return VStack(alignment: .leading, spacing: 0) {
            // Image carousel
            if urls.isEmpty {
                exercisePlaceholder
                    .aspectRatio(16/9, contentMode: .fit)
            } else if urls.count == 1 {
                CachedAsyncImage(url: urls[0]) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    ShimmerView()
                        .aspectRatio(16/9, contentMode: .fit)
                } failure: {
                    exercisePlaceholder
                        .aspectRatio(16/9, contentMode: .fit)
                }
                .clipped()
            } else {
                TabView {
                    ForEach(urls, id: \.self) { url in
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            ShimmerView()
                                .aspectRatio(16/9, contentMode: .fit)
                        } failure: {
                            exercisePlaceholder
                                .aspectRatio(16/9, contentMode: .fit)
                        }
                        .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .aspectRatio(16/9, contentMode: .fit)
            }

            // Details
            VStack(alignment: .leading, spacing: 6) {
                Text(localizedExerciseName(item.name, externalId: item.externalId))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let last = item.lastSet {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Last: \(Self.formatLastSet(last))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.gymBroNeutral600)
                }

                HStack(spacing: 6) {
                    Text(MuscleGroup(rawValue: item.muscleGroup)?.displayName ?? item.muscleGroup)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "2D3240").opacity(0.7))
                        .clipShape(Capsule())

                    Text(EquipmentType(rawValue: item.equipment)?.displayName ?? item.equipment)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gymBroNeutral600)
                        .lineLimit(1)
                }
            }
            .padding(10)
        }
        .background(Color.gymBroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
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
            Text("Create one or save from a completed workout")
                .font(.system(size: 15))
                .foregroundColor(.gymBroNeutral400)
                .multilineTextAlignment(.center)
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
                    name: localizedExerciseName(exercise.name, externalId: exercise.externalId),
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

    private static func formatLastSet(_ set: ExerciseLibraryLastSet) -> String {
        if set.isCardio {
            return WorkoutSnapshotExercise.cardioLine(
                seconds: set.durationSeconds ?? 0,
                meters: set.distanceMeters ?? 0
            )
        }
        let weightPart: String
        if set.isBodyweight {
            weightPart = "BW"
        } else if let w = set.weight {
            weightPart = "\(w.formattedWeight) \(set.weightUnit)"
        } else {
            weightPart = "—"
        }
        return "\(weightPart) × \(set.reps)"
    }
}
