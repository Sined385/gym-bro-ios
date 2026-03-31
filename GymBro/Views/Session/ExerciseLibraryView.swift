import SwiftUI

struct ExerciseLibraryView: View {
    @ObservedObject var viewModel: ExerciseLibraryViewModel
    var addedExerciseIds: Set<String>
    var onExerciseSelected: (ExerciseLibraryItem) -> Void
    var onStartSuperset: () -> Void
    var onCreateCustom: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gymBroNeutral400)

                TextField("Search exercises...", text: $viewModel.searchText)
                    .font(.system(size: 16))
                    .foregroundColor(.gymBroNeutral900)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
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
            MuscleGroupFilterChips(selectedGroup: $viewModel.selectedMuscleGroup)
                .padding(.top, 12)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onStartSuperset) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Start Superset")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "7A82F6"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "7A82F6"), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                Button(action: onCreateCustom) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Create Custom Exercise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.gymBroPrimary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Exercise list
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(.gymBroPrimary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredExercises) { item in
                            let isAdded = addedExerciseIds.contains(item.id)
                            exerciseRow(item, isAdded: isAdded)
                                .onTapGesture {
                                    guard !isAdded else { return }
                                    onExerciseSelected(item)
                                }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.exercises.isEmpty {
                await viewModel.loadExercises()
            }
        }
        .analyticsScreen("ExerciseLibrary")
    }

    private func exerciseRow(_ item: ExerciseLibraryItem, isAdded: Bool) -> some View {
        HStack(spacing: 12) {
            // Exercise image or fallback icon
            if let imageUrl = item.images?.first, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        exercisePlaceholder(isAdded: isAdded)
                    default:
                        ShimmerView()
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(isAdded ? 0.5 : 1)
            } else {
                exercisePlaceholder(isAdded: isAdded)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isAdded ? .gymBroNeutral400 : .gymBroNeutral900)

                HStack(spacing: 8) {
                    Text(item.muscleGroup)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "2D3240").opacity(isAdded ? 0.4 : 0.7))
                        .clipShape(Capsule())

                    Text(item.equipment)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroNeutral600)
                }
            }

            Spacer()

            // Add indicator
            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(isAdded ? Color(hex: "30C08D") : .gymBroNeutral400)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.gymBroBackground)
        .contentShape(Rectangle())
    }

    private func exercisePlaceholder(isAdded: Bool) -> some View {
        ZStack {
            Color(hex: "2D3240").opacity(isAdded ? 0.15 : 0.08)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
        }
    }
}
