//
//  SupersetSelectionView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import SwiftUI

struct SupersetSelectionView: View {
    @ObservedObject var libraryViewModel: ExerciseLibraryViewModel
    @EnvironmentObject var favoritesService: FavoritesService
    var addedExerciseIds: Set<String>
    var onSave: ([ExerciseLibraryItem]) -> Void

    @State private var selectedIds: Set<String> = []

    private var selectedCount: Int { selectedIds.count }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gymBroNeutral400)

                TextField("Search exercises...", text: $libraryViewModel.searchText)
                    .font(.system(size: 16))
                    .foregroundColor(.gymBroNeutral900)

                if !libraryViewModel.searchText.isEmpty {
                    Button {
                        libraryViewModel.searchText = ""
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

            // Category chips
            MuscleGroupFilterChips(selectedGroup: $libraryViewModel.selectedMuscleGroup)
                .padding(.top, 12)

            // Equipment chips
            EquipmentFilterChips(selectedEquipment: $libraryViewModel.selectedEquipment)
                .padding(.top, 8)

            // Save button
            Button {
                let items = libraryViewModel.exercises.filter { selectedIds.contains($0.id) }
                onSave(items)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Save Superset (\(selectedCount) selected)")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    selectedCount >= 2
                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "7A82F6"), Color(hex: "6366F1")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.gymBroNeutral400)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .disabled(selectedCount < 2)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Exercise list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(libraryViewModel.filteredExercises(favoriteIds: favoritesService.favoriteIds)) { item in
                        exerciseCard(item, isAlreadyInSession: addedExerciseIds.contains(item.id))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle("Select Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func imageURLs(for item: ExerciseLibraryItem) -> [URL] {
        let builderURLs = ExerciseImageURLBuilder.imageURLs(for: item.externalId)
        if !builderURLs.isEmpty { return builderURLs }
        return item.images?.compactMap { URL(string: $0) } ?? []
    }

    private func exerciseCard(_ item: ExerciseLibraryItem, isAlreadyInSession: Bool) -> some View {
        let isSelected = selectedIds.contains(item.id)
        let urls = imageURLs(for: item)

        return Button {
            if isSelected {
                selectedIds.remove(item.id)
            } else {
                selectedIds.insert(item.id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Exercise image carousel
                if urls.isEmpty {
                    exercisePlaceholder()
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
                        exercisePlaceholder()
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
                                exercisePlaceholder()
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
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(item.muscleGroup)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "2D3240").opacity(0.7))
                            .clipShape(Capsule())

                        Text(item.equipment)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gymBroNeutral600)
                            .lineLimit(1)

                        Spacer()

                        // Selection indicator
                        ZStack {
                            Circle()
                                .stroke(isSelected ? Color(hex: "7A82F6") : Color.gymBroNeutral200, lineWidth: 2)
                                .frame(width: 26, height: 26)

                            if isSelected {
                                Circle()
                                    .fill(Color(hex: "7A82F6"))
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .background(isSelected ? Color(hex: "7A82F6").opacity(0.05) : Color.gymBroBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "7A82F6") : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func exercisePlaceholder() -> some View {
        ZStack {
            Color(hex: "2D3240").opacity(0.08)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
        }
    }
}
