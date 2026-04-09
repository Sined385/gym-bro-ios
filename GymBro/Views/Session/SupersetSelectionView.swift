//
//  SupersetSelectionView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import SwiftUI

struct SupersetSelectionView: View {
    @ObservedObject var libraryViewModel: ExerciseLibraryViewModel
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
                LazyVStack(spacing: 0) {
                    ForEach(libraryViewModel.filteredExercises) { item in
                        supersetRow(item, isAlreadyInSession: addedExerciseIds.contains(item.id))
                    }
                }
                .padding(.top, 12)
            }
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle("Select Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func supersetRow(_ item: ExerciseLibraryItem, isAlreadyInSession: Bool) -> some View {
        let isSelected = selectedIds.contains(item.id)

        return Button {
            if isSelected {
                selectedIds.remove(item.id)
            } else {
                selectedIds.insert(item.id)
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)

                    HStack(spacing: 8) {
                        Text(item.muscleGroup)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gymBroNeutral600)

                        Text(item.equipment)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)
                    }
                }

                Spacer()

                // Selection toggle
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
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(isSelected ? Color(hex: "7A82F6").opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
