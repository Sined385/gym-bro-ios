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

            // Equipment chips
            EquipmentFilterChips(selectedEquipment: $viewModel.selectedEquipment)
                .padding(.top, 8)

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

            // Exercise grid
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(.gymBroPrimary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredExercises) { item in
                            let isAdded = addedExerciseIds.contains(item.id)
                            exerciseCard(item, isAdded: isAdded)
                                .onTapGesture {
                                    guard !isAdded else { return }
                                    onExerciseSelected(item)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
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

    private func imageURLs(for item: ExerciseLibraryItem) -> [URL] {
        let builderURLs = ExerciseImageURLBuilder.imageURLs(for: item.externalId)
        if !builderURLs.isEmpty { return builderURLs }
        return item.images?.compactMap { URL(string: $0) } ?? []
    }

    private func exerciseCard(_ item: ExerciseLibraryItem, isAdded: Bool) -> some View {
        let urls = imageURLs(for: item)

        return VStack(alignment: .leading, spacing: 0) {
            // Exercise image carousel
            if urls.isEmpty {
                exercisePlaceholder(isAdded: isAdded)
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
                    exercisePlaceholder(isAdded: isAdded)
                        .aspectRatio(16/9, contentMode: .fit)
                }
                .clipped()
                .opacity(isAdded ? 0.5 : 1)
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
                            exercisePlaceholder(isAdded: isAdded)
                                .aspectRatio(16/9, contentMode: .fit)
                        }
                        .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .aspectRatio(16/9, contentMode: .fit)
                .opacity(isAdded ? 0.5 : 1)
            }

            // Details
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isAdded ? .gymBroNeutral400 : .gymBroNeutral900)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(item.muscleGroup)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "2D3240").opacity(isAdded ? 0.4 : 0.7))
                        .clipShape(Capsule())

                    Text(item.equipment)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gymBroNeutral600)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isAdded ? Color(hex: "30C08D") : .gymBroNeutral400)
                }
            }
            .padding(10)
        }
        .background(Color.gymBroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .opacity(isAdded ? 0.7 : 1)
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
