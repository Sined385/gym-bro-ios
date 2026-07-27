import SwiftUI

struct ExerciseLibraryView: View {
    @ObservedObject var viewModel: ExerciseLibraryViewModel
    @EnvironmentObject var favoritesService: FavoritesService
    @EnvironmentObject var sessionManager: ActiveSessionManager
    var addedExerciseIds: Set<String> = []
    var onExerciseSelected: ((ExerciseLibraryItem) -> Void)? = nil
    var onStartSuperset: (() -> Void)? = nil
    var onCreateCustom: (() -> Void)? = nil

    /// When true, the screen is a read-only browse experience launched
    /// from Profile. Picker affordances (Start Superset, Create Custom,
    /// per-row add/remove icon, "already added" green border) hide; a
    /// tap on a row pushes the rich exercise detail view powered by
    /// ExerciseLoggingView in readOnly mode.
    var browseMode: Bool = false

    @State private var browseDetailItem: ExerciseLibraryItem?

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

            // Action buttons — picker mode only.
            if !browseMode {
                HStack(spacing: 12) {
                    Button { onStartSuperset?() } label: {
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

                    Button { onCreateCustom?() } label: {
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
            }

            // Exercise grid
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(.gymBroPrimary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredExercises(favoriteIds: favoritesService.favoriteIds)) { item in
                            let isAdded = addedExerciseIds.contains(item.id)
                            exerciseCard(item, isAdded: isAdded)
                                .onTapGesture {
                                    if browseMode {
                                        browseDetailItem = item
                                    } else {
                                        // Picker mode — tap toggles:
                                        // add → remove → add. Selection
                                        // visuals (green border + checkmark)
                                        // reflect current state.
                                        onExerciseSelected?(item)
                                    }
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
        .navigationDestination(item: $browseDetailItem) { item in
            ExerciseBrowseDetailView(item: item)
        }
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

                    Spacer()

                    favoriteHeart(for: item)

                    if !browseMode {
                        Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isAdded ? Color(hex: "30C08D") : .gymBroNeutral400)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "D4D4D4"))
                    }
                }
            }
            .padding(10)
        }
        .background(Color.gymBroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // "Already added" indicator: green border replaces the prior whole-card
        // opacity dim, which made added cards look broken rather than confirmed.
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isAdded && !browseMode ? Color(hex: "30C08D") : .clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
    }

    private func favoriteHeart(for item: ExerciseLibraryItem) -> some View {
        let isFavorite = favoritesService.isFavorite(item.id)
        return Image(systemName: isFavorite ? "heart.fill" : "heart")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(isFavorite ? .gymBroPrimary : .gymBroNeutral400)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            // Run before the card-level onTapGesture so the heart tap doesn't
            // also fire the "select this exercise" action.
            .highPriorityGesture(
                TapGesture().onEnded {
                    Task { await favoritesService.toggle(exerciseId: item.id) }
                }
            )
    }

    private func exercisePlaceholder(isAdded: Bool) -> some View {
        ZStack {
            Color(hex: "2D3240").opacity(isAdded ? 0.15 : 0.08)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
        }
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

/// Browse-mode detail destination. Wraps ExerciseLoggingView(readOnly: true)
/// with a transient SessionFlowViewModel constructed in isPreviewMode so
/// the live session's watch callbacks, Live-Activity subscription, and
/// server sync are NOT touched. The viewModel holds a single derived
/// ActiveSessionExercise with empty sets; ExerciseLoggingView fetches
/// history via the library exercise id and renders image, History, and
/// Stats just like inside an active workout — minus every logging
/// affordance.
struct ExerciseBrowseDetailView: View {
    let item: ExerciseLibraryItem
    @StateObject private var previewVM: SessionFlowViewModel
    private let previewExerciseId: String

    init(item: ExerciseLibraryItem) {
        self.item = item
        let activeExercise = ActiveSessionExercise(
            id: item.id,
            libraryExerciseId: item.id,
            name: item.name,
            muscleGroup: item.muscleGroup,
            equipment: item.equipment,
            accentColor: "#E86A75",
            stepNumber: 0,
            sets: [],
            supersetGroupId: nil,
            supersetOrder: nil,
            targetSets: 0,
            targetReps: 0,
            imageUrl: item.images?.first,
            externalId: item.externalId,
            isFavorite: item.isFavorite,
        )
        self.previewExerciseId = activeExercise.id
        let container = DependencyContainer.shared
        let vm = SessionFlowViewModel(
            sessionId: "library-preview",
            sessionTitle: "Library Preview",
            networkService: container.resolve(NetworkServiceProtocol.self),
            sessionManager: container.resolve(ActiveSessionManager.self),
            healthKitService: container.resolve(HealthKitServiceProtocol.self),
            analyticsService: container.resolve(AnalyticsTrackingServiceProtocol.self),
            restoredExercises: [activeExercise],
            isPreviewMode: true,
        )
        _previewVM = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ExerciseLoggingView(
            viewModel: previewVM,
            exerciseId: previewExerciseId,
            readOnly: true,
        )
    }
}
