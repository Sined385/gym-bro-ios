//
//  ExerciseLoggingView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import SwiftUI

struct ExerciseLoggingView: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @EnvironmentObject var favoritesService: FavoritesService
    @ObservedObject var viewModel: SessionFlowViewModel

    // Individual mode
    var exerciseId: String? = nil
    // Superset mode
    var supersetGroupId: String? = nil

    /// Replaces the top of the parent's navigation stack with the next standalone exercise.
    var onSwitchToExercise: ((String) -> Void)? = nil
    /// Replaces the top of the parent's navigation stack with the next superset.
    var onSwitchToSuperset: ((String) -> Void)? = nil
    /// Pushes the workout-feedback step. Wired up so the bottom peek card
    /// can become an "End Workout" CTA when this is the last exercise.
    var onEndWorkout: (() -> Void)? = nil

    /// View-only mode (library detail). Hides every logging affordance:
    /// the Today card (live editable set rows + Add Set), the Live
    /// Comparison card, and the per-history-row pencil/repeat buttons.
    /// Image carousel, History list, and Stats tab stay so the library
    /// detail uses the same look as the in-workout view.
    var readOnly: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var previousSessions: [String: [PreviousSessionEntry]] = [:]
    @State private var showAddSetSheet: Bool = false
    @State private var addSetWeight: String = ""
    @State private var addSetReps: String = ""
    @State private var addSetIsBodyweight: Bool = false

    // Edit mode: when non-nil, the modal edits an existing set instead of adding
    @State private var editingSetInfo: (exerciseId: String, setId: String)?

    // Expanded gallery viewer
    @State private var showExpandedGallery: Bool = false
    @State private var expandedGalleryUrls: [URL] = []
    @State private var expandedGalleryIndex: Int = 0

    // Inline editing state for pre-populated sets
    @State private var editWeights: [String: String] = [:]
    @State private var editReps: [String: String] = [:]
    @State private var editBodyweight: [String: Bool] = [:]

    // Detail view tab — switches between live session UI and the perf graph
    enum DetailTab: String, CaseIterable, Identifiable {
        case today, stats
        var id: String { rawValue }
        var label: String {
            switch self {
            case .today: return "Today"
            case .stats: return "Stats"
            }
        }
    }
    @State private var detailTab: DetailTab = .today

    // Superset step-through state
    @State private var supersetStepIndex: Int = 0
    @State private var supersetSetEntries: [(exerciseId: String, weight: Double?, reps: Int, isBodyweight: Bool)] = []
    @State private var roundOffsets: [Int: CGFloat] = [:]
    @State private var editingRoundIndex: Int? = nil

    private let greenAccent = Color(hex: "30C08D")
    private let purpleAccent = Color(hex: "7A82F6")

    private var isSuperset: Bool { supersetGroupId != nil }

    private var exercise: ActiveSessionExercise? {
        guard let exerciseId = exerciseId else { return nil }
        return viewModel.exercises.first { $0.id == exerciseId }
    }

    private var supersetGroup: SupersetGroup? {
        guard let groupId = supersetGroupId else { return nil }
        return viewModel.supersetGroups.first { $0.id == groupId }
    }

    private var exerciseIndex: String {
        guard let exercise = exercise else { return "" }
        let idx = viewModel.exercises.firstIndex(where: { $0.id == exercise.id }).map { $0 + 1 } ?? 0
        return "\(idx) OF \(viewModel.exercises.count)"
    }

    private var hasNextTarget: Bool {
        viewModel.nextWorkoutTarget(
            afterExerciseId: exerciseId,
            afterSupersetGroupId: supersetGroupId
        ) != nil
    }

    private var bottomScrollClearance: CGFloat {
        if sessionManager.isResting { return 120 }
        if hasNextTarget { return 96 }
        return 40
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                headerSection

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isSuperset, let group = supersetGroup {
                            supersetContent(group)
                        } else if let exercise = exercise {
                            individualContent(exercise)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, bottomScrollClearance)
                }
            }
            .background(Color.gymBroBackground.ignoresSafeArea())

            // Floating rest timer bar — when running, the timer takes
            // priority over the up-next peek card to keep the bottom
            // edge from getting too busy.
            if let remaining = sessionManager.restTimeRemaining {
                restTimerBar(remaining)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                nextExercisePeekCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: sessionManager.restTimeRemaining)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddSetSheet) {
            editingSetInfo = nil
        } content: {
            addSetModal
                .presentationDetents([.height(isSupersetModal ? 360 : 280)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .task {
            await loadPreviousData()
        }
        // Tell the Watch which exercise the phone has open so it stays in
        // sync. Cleared on disappear so the Watch can fall back to its own
        // first-incomplete heuristic when the phone is away from a specific
        // exercise.
        .onAppear { sessionManager.setPhoneActiveExercise(activeExerciseIdForWatch) }
        .onDisappear { sessionManager.setPhoneActiveExercise(nil) }
        .onChange(of: supersetStepIndex) {
            sessionManager.setPhoneActiveExercise(activeExerciseIdForWatch)
        }
        .analyticsScreen("ExerciseLogging")
    }

    /// What to pin on the Watch for this view: the individual exercise id, or
    /// the currently-shown step of a superset.
    private var activeExerciseIdForWatch: String? {
        if let exerciseId { return exerciseId }
        if let group = supersetGroup, supersetStepIndex < group.exercises.count {
            return group.exercises[supersetStepIndex].id
        }
        return nil
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            // Back button
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .stroke(Color.gymBroNeutral100, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Center: exercise counter + timer
            VStack(spacing: 2) {
                if !isSuperset {
                    Text("EXERCISE \(exerciseIndex)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundColor(.gymBroPrimary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 14))
                        .foregroundColor(.gymBroNeutral600)
                    Text(sessionManager.formattedTime)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(.gymBroNeutral900)
                }
            }

            Spacer()

            if let libraryId = exercise?.libraryExerciseId {
                favoriteHeartButton(libraryExerciseId: libraryId)
            } else {
                // Balance the back button width when no heart is shown.
                Color.clear.frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Next Exercise Peek Card

    /// Bottom-anchored mini card that "peeks" up from the screen edge,
    /// styled like an Apple Music mini-player. Drag handle at top, "UP
    /// NEXT" label + exercise name in the body, chevron on the trailing
    /// edge. Tap to jump to that exercise — or, when this is the last
    /// exercise in the workout, the same slot becomes an "End Workout" CTA.
    @ViewBuilder
    private var nextExercisePeekCard: some View {
        if let target = viewModel.nextWorkoutTarget(
            afterExerciseId: exerciseId,
            afterSupersetGroupId: supersetGroupId
        ) {
            peekCardButton(eyebrow: "UP NEXT", label: target.label, iconName: "arrow.right") {
                switch target {
                case .exercise(let id, _):
                    onSwitchToExercise?(id)
                case .superset(let groupId, _):
                    onSwitchToSuperset?(groupId)
                }
            }
        } else if let onEndWorkout {
            peekCardButton(eyebrow: "FINISH", label: "End Workout", iconName: "checkmark") {
                onEndWorkout()
            }
        }
    }

    private func peekCardButton(
        eyebrow: String,
        label: String,
        iconName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Small accent badge
                    ZStack {
                        Circle()
                            .fill(Color.gymBroPrimary.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: iconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gymBroPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(eyebrow)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.9)
                            .foregroundColor(.gymBroNeutral400)
                        Text(label)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.gymBroNeutral900)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gymBroNeutral400)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
                .ignoresSafeArea(edges: .bottom)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: -4)
        }
        .buttonStyle(.plain)
    }

    private func favoriteHeartButton(libraryExerciseId: String) -> some View {
        let isFavorite = favoritesService.isFavorite(libraryExerciseId)
        return Button {
            Task { await favoritesService.toggle(exerciseId: libraryExerciseId) }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle()
                            .stroke(Color.gymBroNeutral100, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFavorite ? .gymBroPrimary : .gymBroNeutral900)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Individual Content

    private func individualContent(_ exercise: ActiveSessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Exercise name
            Text(exercise.name)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.5)
                .foregroundColor(.gymBroNeutral900)

            // Exercise image hint — horizontal carousel
            let imageURLs = ExerciseImageURLBuilder.imageURLs(for: exercise.externalId)
            if !imageURLs.isEmpty {
                TabView {
                    ForEach(imageURLs, id: \.absoluteString) { imgUrl in
                        CachedAsyncImage(url: imgUrl) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    expandedGalleryUrls = imageURLs
                                    expandedGalleryIndex = imageURLs.firstIndex(of: imgUrl) ?? 0
                                    showExpandedGallery = true
                                }
                        } placeholder: {
                            ShimmerView()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } failure: {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gymBroNeutral100)
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gymBroNeutral400)
                                )
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .automatic : .never))
                .frame(height: 220)
                .background(
                    ExpandedGalleryView(
                        urls: expandedGalleryUrls,
                        initialIndex: expandedGalleryIndex,
                        isPresented: $showExpandedGallery
                    )
                    .frame(width: 0, height: 0)
                )
            }

            // Today / Stats segmented control
            detailTabPicker

            // Tab content
            if detailTab == .today {
                if !readOnly {
                    liveComparisonCard(for: exercise)
                    todayCard(for: exercise)
                }

                if let sessions = previousSessions[exercise.id], !sessions.isEmpty {
                    previousSessionsSection(sessions, exercise: exercise)
                }
            } else {
                ExercisePerformanceView(
                    exercise: exercise,
                    previousSessions: previousSessions[exercise.id] ?? []
                )
            }
        }
    }

    // MARK: - Detail Tab Picker

    private var detailTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { detailTab = tab }
                } label: {
                    Text(tab.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(detailTab == tab ? .gymBroNeutral900 : .gymBroNeutral400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(detailTab == tab ? Color.white : .clear)
                                .shadow(color: detailTab == tab ? .black.opacity(0.06) : .clear, radius: 2, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.gymBroNeutral100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Live Comparison Card

    private func liveComparisonCard(for exercise: ActiveSessionExercise) -> some View {
        let prevSets = lastSessionSets(for: exercise.id)
        let currentSets = exercise.sets.filter { $0.isCompleted }

        let totalVolume = currentSets.reduce(0.0) { $0 + (($1.weight ?? 0) * Double($1.reps ?? 0)) }
        let avgWeight = currentSets.isEmpty ? 0.0 : currentSets.reduce(0.0) { $0 + ($1.weight ?? 0) } / Double(currentSets.count)
        let totalReps = currentSets.reduce(0) { $0 + ($1.reps ?? 0) }
        let setCount = currentSets.count

        let hasPrevData = !prevSets.isEmpty
        let prevVolume = prevSets.reduce(0.0) { $0 + (($1.weight ?? 0) * Double($1.reps)) }
        let prevAvgWeight = prevSets.isEmpty ? 0.0 : prevSets.reduce(0.0) { $0 + ($1.weight ?? 0) } / Double(prevSets.count)
        let prevTotalReps = prevSets.reduce(0) { $0 + $1.reps }
        let prevSetCount = prevSets.count

        return VStack(spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gymBroNeutral400)
                Text("LIVE COMPARISON VS LAST SESSION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(.gymBroNeutral400)
                Spacer()
            }

            // Stats grid
            let hasToday = !currentSets.isEmpty
            HStack(spacing: 12) {
                comparisonStat(
                    label: "VOLUME",
                    value: hasToday ? "\(Int(totalVolume))kg" : "--",
                    todayValue: hasToday ? Int(totalVolume) : nil,
                    prevValue: hasPrevData ? Int(prevVolume) : nil
                )
                comparisonStat(
                    label: "AVG WT",
                    value: hasToday ? "\(Int(avgWeight))kg" : "--",
                    todayValue: hasToday ? Int(avgWeight) : nil,
                    prevValue: hasPrevData ? Int(prevAvgWeight) : nil
                )
                comparisonStat(
                    label: "REPS",
                    value: hasToday ? "\(totalReps)" : "--",
                    todayValue: hasToday ? totalReps : nil,
                    prevValue: hasPrevData ? prevTotalReps : nil
                )
                comparisonStat(
                    label: "SETS",
                    value: hasToday ? "\(setCount)" : "--",
                    todayValue: hasToday ? setCount : nil,
                    prevValue: hasPrevData ? prevSetCount : nil
                )
            }
        }
        .padding(16)
        .background(Color.gymBroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 10, y: 2)
        .overlay(alignment: .topTrailing) {
            // Decorative layered icon
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 48))
                .foregroundColor(.gymBroNeutral200.opacity(0.4))
                .padding(.top, -8)
                .padding(.trailing, 8)
        }
    }

    private func comparisonStat(label: String, value: String, todayValue: Int?, prevValue: Int?) -> some View {
        let delta: Int? = {
            guard let today = todayValue, let prev = prevValue else { return nil }
            return today - prev
        }()

        return VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.gymBroNeutral400)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(todayValue != nil ? .gymBroNeutral900 : .gymBroNeutral400)

            if let delta = delta {
                let isUp = delta > 0
                let isDown = delta < 0
                let arrow = isUp ? "arrow.up.right" : (isDown ? "arrow.down.right" : "equal")
                let color: Color = isUp ? Color(hex: "30C08D") : (isDown ? .gymBroPrimary : .gymBroNeutral400)

                HStack(spacing: 2) {
                    Image(systemName: arrow)
                        .font(.system(size: 8, weight: .bold))
                    Text(delta == 0 ? "0" : "\(abs(delta))")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
            } else {
                Text("--")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gymBroNeutral400)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gymBroNeutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Today Card

    /// Returns the best prefill weight/reps for a set: last completed today's set → previous session set → nil
    private func prefillValues(for set: ActiveSet, exercise: ActiveSessionExercise, prevSet: PreviousSet?) -> (weight: Double?, reps: Int?) {
        // First priority: last completed set in today's session (the one right before this set)
        let lastCompleted = exercise.sets
            .filter { $0.isCompleted && $0.setNumber < set.setNumber }
            .last
        if let w = lastCompleted?.weight ?? lastCompleted?.reps.flatMap({ _ in lastCompleted?.weight }),
           let r = lastCompleted?.reps {
            return (w, r)
        }
        if let lc = lastCompleted, (lc.weight != nil || lc.reps != nil) {
            return (lc.weight, lc.reps)
        }
        // Fallback: previous session data
        return (prevSet?.weight, prevSet?.reps)
    }

    @ViewBuilder
    private func setInputRow(exercise: ActiveSessionExercise, set: ActiveSet, prevSet: PreviousSet?) -> some View {
        let prefill = prefillValues(for: set, exercise: exercise, prevSet: prevSet)
        let prefillWeight = prefill.weight
        let prefillReps = prefill.reps
        let prevUnit = prevSet?.weightUnit ?? "kg"

        SwipeableSetRow {
            SetInputRow(
                setNumber: set.setNumber,
                previousWeight: prevSet?.weight,
                previousReps: prevSet?.reps,
                previousWeightUnit: prevUnit,
                previousIsBodyweight: prevSet?.isBodyweight ?? false,
                weight: weightBinding(for: set, previous: prefillWeight),
                reps: repsBinding(for: set, previous: prefillReps),
                isBodyweight: bodyweightBinding(for: set, exercise: exercise),
                isCompleted: set.isCompleted,
                onComplete: {
                    // Default BW state mirrors `bodyweightBinding` so the
                    // inline checkmark on a planned BW-equipment set completes
                    // as bodyweight (matches what the row already displays).
                    let defaultBW = set.isBodyweight || exercise.equipment == "Bodyweight"
                    let isBW = editBodyweight[set.id] ?? defaultBW
                    let wStr: String = editWeights[set.id] ?? set.weight.map { $0.formattedWeight } ?? prefillWeight.map { $0.formattedWeight } ?? ""
                    let rStr: String = editReps[set.id] ?? set.reps.map { "\($0)" } ?? prefillReps.map { "\($0)" } ?? ""
                    let w = isBW ? nil : Double(wStr)
                    let r = Int(rStr) ?? 0
                    Task {
                        await viewModel.completeSet(
                            exerciseId: exercise.id,
                            setId: set.id,
                            weight: w,
                            reps: r,
                            isBodyweight: isBW
                        )
                    }
                    sessionManager.startRestTimer()
                },
                onTapCompleted: {
                    // Fires for both planned and completed sets now. Pre-fill
                    // the popup with the existing values, falling back to the
                    // prefill (last completed today → previous session) so the
                    // user isn't starting from blank fields on a planned set.
                    editingSetInfo = (exerciseId: exercise.id, setId: set.id)
                    addSetWeight = (set.weight ?? prefillWeight).map { $0.formattedWeight } ?? ""
                    addSetReps = (set.reps ?? prefillReps).map { "\($0)" } ?? ""
                    // Honor the set's own flag if it was already toggled,
                    // otherwise fall back to the exercise's equipment default
                    // (bodyweight exercises start with BW pre-selected).
                    addSetIsBodyweight = set.isCompleted
                        ? set.isBodyweight
                        : (set.isBodyweight || exercise.equipment == "Bodyweight")
                    showAddSetSheet = true
                }
            )
        } onDelete: {
            Task {
                await viewModel.deleteSet(exerciseId: exercise.id, setId: set.id)
            }
        } onRepeat: {
            Task {
                await viewModel.logSet(
                    exerciseId: exercise.id,
                    weight: set.isBodyweight ? nil : set.weight,
                    weightUnit: set.weightUnit,
                    reps: set.reps ?? 0,
                    isBodyweight: set.isBodyweight
                )
                sessionManager.startRestTimer()
            }
        }
    }

    private func bodyweightBinding(for set: ActiveSet, exercise: ActiveSessionExercise) -> Binding<Bool> {
        Binding(
            get: {
                // 1. User-toggled value in this session always wins.
                if let override = editBodyweight[set.id] { return override }
                // 2. Persisted on the set itself (re-edit of a completed bodyweight set).
                if set.isBodyweight { return true }
                // 3. New row on a Bodyweight-equipment exercise defaults ON.
                return !set.isCompleted && exercise.equipment == "Bodyweight"
            },
            set: { newValue in
                editBodyweight[set.id] = newValue
                if newValue { editWeights[set.id] = "" }
            }
        )
    }

    private func lastSessionSets(for exerciseId: String) -> [PreviousSet] {
        previousSessions[exerciseId]?.first?.sets ?? []
    }

    private func todayCard(for exercise: ActiveSessionExercise) -> some View {
        let lastSets = lastSessionSets(for: exercise.id)

        return VStack(alignment: .leading, spacing: 16) {
            // Header: "Today" with red dot
            HStack(spacing: 4) {
                Text("Today")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                ZStack {
                    Circle()
                        .fill(Color.gymBroPrimary.opacity(0.8))
                        .frame(width: 15, height: 15)
                        .blur(radius: 3)
                    Circle()
                        .fill(Color.gymBroPrimaryDark)
                        .frame(width: 8, height: 8)
                }
            }

            // Set rows
            VStack(spacing: 8) {
                ForEach(exercise.sets) { set in
                    let prevSet = lastSets.first { $0.setNumber == set.setNumber }
                    setInputRow(exercise: exercise, set: set, prevSet: prevSet)
                }
            }

            // Add Set dashed button
            addSetDashedButton {
                editingSetInfo = nil
                // Pre-fill: last completed today's set → previous session set
                let lastCompleted = exercise.sets.filter { $0.isCompleted }.last
                if let lc = lastCompleted, (lc.weight != nil || lc.reps != nil || lc.isBodyweight) {
                    addSetWeight = lc.weight.map { $0.formattedWeight } ?? ""
                    addSetReps = lc.reps.map { "\($0)" } ?? ""
                    addSetIsBodyweight = lc.isBodyweight
                } else {
                    let nextSetNumber = exercise.sets.count + 1
                    let prevSet = lastSets.first { $0.setNumber == nextSetNumber }
                    addSetWeight = prevSet?.weight.map { $0.formattedWeight } ?? ""
                    addSetReps = prevSet.map { "\($0.reps)" } ?? ""
                    // No history → equipment default.
                    addSetIsBodyweight = prevSet?.isBodyweight ?? (exercise.equipment == "Bodyweight")
                }
                showAddSetSheet = true
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }

    // MARK: - Previous Sessions Section

    private func previousSessionsSection(_ sessions: [PreviousSessionEntry], exercise: ActiveSessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroNeutral400)
                Text("HISTORY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(.gymBroNeutral400)
                Spacer()
            }

            ForEach(sessions) { session in
                VStack(alignment: .leading, spacing: 8) {
                    Text(formattedSessionDate(session.sessionDate))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    ForEach(Array(session.sets.enumerated()), id: \.element.id) { idx, set in
                        previousSetRow(set, exercise: exercise)
                        if idx < session.sets.count - 1 {
                            Divider().background(Color.gymBroNeutral100)
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gymBroNeutral100, lineWidth: 1)
                )
            }
        }
    }

    /// Single row in the history list. Two affordances on the right:
    /// pencil = open the Log Set modal pre-filled with this set's values
    /// so the user can tweak before logging; yellow repeat = log it now
    /// as-is. Repeat button matches the swipe-right repeat on current sets
    /// so the action reads as the same gesture, different surface.
    private func previousSetRow(_ set: PreviousSet, exercise: ActiveSessionExercise) -> some View {
        HStack(spacing: 12) {
            Text("Set \(set.setNumber)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
                .frame(width: 48, alignment: .leading)

            Text(SetDisplay.line(
                weight: set.weight,
                weightUnit: set.weightUnit,
                reps: set.reps,
                isBodyweight: set.isBodyweight
            ))
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.gymBroNeutral900)

            Spacer()

            if !readOnly {
                Button { prefillModalFromPrevious(set) } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .frame(width: 32, height: 32)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gymBroNeutral200, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button { Task { await repeatPreviousSet(set, on: exercise) } } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F59E0B"))
                            .frame(width: 32, height: 32)
                            .shadow(color: Color(hex: "F59E0B").opacity(0.3), radius: 4, y: 2)
                        Image(systemName: "repeat")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    /// Open the existing Log Set modal pre-filled with a previous set's
    /// values. User can edit weight/reps and confirm to log in the current
    /// session. `editingSetInfo`/`editingRoundIndex` cleared so it's an
    /// add-new-set flow, not an edit-existing-set flow.
    private func prefillModalFromPrevious(_ set: PreviousSet) {
        addSetWeight = set.weight.map { $0.formattedWeight } ?? ""
        addSetReps = "\(set.reps)"
        addSetIsBodyweight = set.isBodyweight
        editingSetInfo = nil
        editingRoundIndex = nil
        showAddSetSheet = true
    }

    /// Logs the previous set as-is in the current session.
    private func repeatPreviousSet(_ set: PreviousSet, on exercise: ActiveSessionExercise) async {
        await viewModel.logSet(
            exerciseId: exercise.id,
            weight: set.isBodyweight ? nil : set.weight,
            weightUnit: set.weightUnit,
            reps: set.reps,
            isBodyweight: set.isBodyweight
        )
        sessionManager.startRestTimer()
    }

    private func formattedSessionDate(_ isoDate: String?) -> String {
        guard let isoDate = isoDate else { return "Previous Session" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
        guard let date = date else { return isoDate }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Set Bindings

    private func weightBinding(for set: ActiveSet, previous: Double? = nil) -> Binding<String> {
        Binding(
            get: { editWeights[set.id] ?? set.weight.map { $0.formattedWeight } ?? previous.map { $0.formattedWeight } ?? "" },
            set: { editWeights[set.id] = $0 }
        )
    }

    private func repsBinding(for set: ActiveSet, previous: Int? = nil) -> Binding<String> {
        Binding(
            get: { editReps[set.id] ?? set.reps.map { "\($0)" } ?? previous.map { "\($0)" } ?? "" },
            set: { editReps[set.id] = $0 }
        )
    }

    // MARK: - Superset Content

    private func supersetContent(_ group: SupersetGroup) -> some View {
        let maxSets = group.exercises.map { $0.sets.count }.max() ?? 0

        return VStack(alignment: .leading, spacing: 16) {
            // Superset badge
            HStack(spacing: 6) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("SUPERSET")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(purpleAccent)
            .clipShape(Capsule())

            // Exercise labels
            ForEach(group.exercises) { ex in
                HStack(spacing: 8) {
                    Text(ex.supersetOrder ?? "")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(purpleAccent)
                    Text(ex.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                }
            }

            // Today header
            HStack(spacing: 4) {
                Text("Today")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                ZStack {
                    Circle().fill(purpleAccent.opacity(0.8)).frame(width: 15, height: 15).blur(radius: 3)
                    Circle().fill(purpleAccent).frame(width: 8, height: 8)
                }
            }

            // Round cards
            ForEach(0..<maxSets, id: \.self) { roundIndex in
                let allCompleted = group.exercises.allSatisfy { ex in
                    roundIndex < ex.sets.count && ex.sets[roundIndex].isCompleted
                }
                if allCompleted {
                    supersetCompletedRound(group: group, roundIndex: roundIndex)
                } else {
                    supersetEditableRound(group: group, roundIndex: roundIndex)
                }
            }

            // Add Round button
            addSetDashedButton {
                editingRoundIndex = nil
                supersetStepIndex = 0
                supersetSetEntries = []
                addSetWeight = ""
                addSetReps = ""
                // Default the first step's toggle from the first exercise's equipment.
                addSetIsBodyweight = group.exercises.first?.equipment == "Bodyweight"
                editingSetInfo = nil
                showAddSetSheet = true
            }
        }
    }

    // MARK: - Superset Completed Round

    private func supersetCompletedRound(group: SupersetGroup, roundIndex: Int) -> some View {
        let offset = roundOffsets[roundIndex] ?? 0
        let threshold: CGFloat = 70

        return ZStack {
            // Delete button (swipe left)
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        roundOffsets[roundIndex] = -400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        deleteRound(group: group, roundIndex: roundIndex)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FB2C36"))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: "FB2C36").opacity(0.3), radius: 6, y: 2)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .opacity(min(Double(abs(min(offset, 0)) / threshold), 1.0))
                .padding(.trailing, 12)
            }

            // Repeat button (swipe right)
            HStack {
                Button {
                    repeatRound(group: group, roundIndex: roundIndex)
                    withAnimation(.spring(response: 0.3)) { roundOffsets[roundIndex] = 0 }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F59E0B"))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: "F59E0B").opacity(0.3), radius: 6, y: 2)
                        Image(systemName: "repeat")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .opacity(min(Double(max(offset, 0) / threshold), 1.0))
                .padding(.leading, 12)
                Spacer()
            }

            // Round card content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ROUND \(roundIndex + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(purpleAccent)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(greenAccent)
                }

                ForEach(group.exercises) { ex in
                    if let set = roundIndex < ex.sets.count ? ex.sets[roundIndex] : nil {
                        HStack(spacing: 8) {
                            Text(ex.supersetOrder ?? "")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(purpleAccent)
                                .frame(width: 18)

                            Text(ex.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gymBroNeutral600)
                                .lineLimit(1)

                            Spacer()

                            Text(SetDisplay.line(
                                weight: set.weight,
                                weightUnit: set.weightUnit,
                                reps: set.reps,
                                isBodyweight: set.isBodyweight
                            ))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                        }
                    }
                }
            }
            .padding(14)
            .background(purpleAccent.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(purpleAccent.opacity(0.15), lineWidth: 1)
            )
            .offset(x: offset)
            .contentShape(Rectangle())
            .onTapGesture {
                editRound(group: group, roundIndex: roundIndex)
            }
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        roundOffsets[roundIndex] = value.translation.width * 0.7
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            let cur = roundOffsets[roundIndex] ?? 0
                            if cur < -threshold / 2 {
                                roundOffsets[roundIndex] = -threshold
                            } else if cur > threshold / 2 {
                                roundOffsets[roundIndex] = threshold
                            } else {
                                roundOffsets[roundIndex] = 0
                            }
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Superset Editable Round

    private func supersetEditableRound(group: SupersetGroup, roundIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ROUND \(roundIndex + 1)")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundColor(purpleAccent)

            ForEach(group.exercises) { ex in
                let set: ActiveSet? = roundIndex < ex.sets.count ? ex.sets[roundIndex] : nil

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(ex.supersetOrder ?? "")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(purpleAccent)
                        Text(ex.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        ZStack(alignment: .trailing) {
                            TextField("", text: supersetFieldBinding(
                                dict: $editWeights,
                                set: set,
                                fallbackKey: "\(ex.id)-w-\(roundIndex)",
                                existing: set?.weight.map { $0.formattedWeight }
                            ))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(purpleAccent.opacity(0.3), lineWidth: 1)
                            )

                            let weightKey = set?.id ?? "\(ex.id)-w-\(roundIndex)"
                            if (editWeights[weightKey] ?? set?.weight.map { $0.formattedWeight } ?? "").isEmpty {
                                Text("kg")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gymBroNeutral400)
                                    .padding(.trailing, 10)
                                    .allowsHitTesting(false)
                            }
                        }

                        Text("\u{00D7}")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)

                        TextField("", text: supersetFieldBinding(
                            dict: $editReps,
                            set: set,
                            fallbackKey: "\(ex.id)-r-\(roundIndex)",
                            existing: set?.reps.map { "\($0)" }
                        ))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(purpleAccent.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }

            // Complete Round button
            Button {
                completeRound(group: group, roundIndex: roundIndex)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                    Text("Complete Round")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: [purpleAccent, Color(hex: "6366F1")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: purpleAccent.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(purpleAccent.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    // MARK: - Superset Field Binding

    private func supersetFieldBinding(dict: Binding<[String: String]>, set: ActiveSet?, fallbackKey: String, existing: String?) -> Binding<String> {
        let key = set?.id ?? fallbackKey
        return Binding(
            get: { dict.wrappedValue[key] ?? existing ?? "" },
            set: { dict.wrappedValue[key] = $0 }
        )
    }

    // MARK: - Superset Round Actions

    private func completeRound(group: SupersetGroup, roundIndex: Int) {
        for ex in group.exercises {
            guard roundIndex < ex.sets.count else { continue }
            let set = ex.sets[roundIndex]
            let wKey = set.id
            let rKey = set.id
            let wStr = editWeights[wKey] ?? set.weight.map { $0.formattedWeight } ?? ""
            let rStr = editReps[rKey] ?? set.reps.map { "\($0)" } ?? ""
            let w = Double(wStr.replacingOccurrences(of: ",", with: "."))
            let r = Int(rStr) ?? 0
            Task {
                await viewModel.completeSet(exerciseId: ex.id, setId: set.id, weight: w, reps: r)
            }
        }
        sessionManager.startRestTimer()
    }

    private func deleteRound(group: SupersetGroup, roundIndex: Int) {
        for ex in group.exercises {
            guard roundIndex < ex.sets.count else { continue }
            let setId = ex.sets[roundIndex].id
            Task { await viewModel.deleteSet(exerciseId: ex.id, setId: setId) }
        }
        roundOffsets.removeValue(forKey: roundIndex)
    }

    private func repeatRound(group: SupersetGroup, roundIndex: Int) {
        for ex in group.exercises {
            guard roundIndex < ex.sets.count else { continue }
            let set = ex.sets[roundIndex]
            Task {
                await viewModel.logSet(
                    exerciseId: ex.id,
                    weight: set.isBodyweight ? nil : set.weight,
                    reps: set.reps ?? 0,
                    isBodyweight: set.isBodyweight
                )
            }
        }
    }

    private func editRound(group: SupersetGroup, roundIndex: Int) {
        editingRoundIndex = roundIndex
        editingSetInfo = nil
        supersetStepIndex = 0
        supersetSetEntries = []
        if let firstEx = group.exercises.first, roundIndex < firstEx.sets.count {
            let set = firstEx.sets[roundIndex]
            addSetWeight = set.weight.map { $0.formattedWeight } ?? ""
            addSetReps = set.reps.map { "\($0)" } ?? ""
            addSetIsBodyweight = set.isBodyweight
        } else {
            addSetWeight = ""
            addSetReps = ""
            addSetIsBodyweight = group.exercises.first?.equipment == "Bodyweight"
        }
        showAddSetSheet = true
    }

    // MARK: - Add Set Dashed Button

    private func addSetDashedButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Add Set")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(Color(hex: "737373"))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundColor(Color.gymBroNeutral200)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Set Modal (Bottom Sheet)

    /// Current superset exercise being entered (nil for individual mode)
    private var currentSupersetExercise: ActiveSessionExercise? {
        guard let group = supersetGroup,
              supersetStepIndex < group.exercises.count else { return nil }
        return group.exercises[supersetStepIndex]
    }

    private var isSupersetModal: Bool {
        supersetGroup != nil
    }

    private var isLastSupersetStep: Bool {
        guard let group = supersetGroup else { return true }
        return supersetStepIndex >= group.exercises.count - 1
    }

    private var addSetModal: some View {
        VStack(spacing: 24) {
            // Title — shows exercise name for superset step-through
            if isSupersetModal, let currentEx = currentSupersetExercise {
                VStack(spacing: 4) {
                    // Step indicator
                    HStack(spacing: 6) {
                        Text("\(currentEx.supersetOrder ?? "")")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(purpleAccent)
                        Text("\(supersetStepIndex + 1) of \(supersetGroup?.exercises.count ?? 0)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)
                    }
                    .padding(.top, 28)

                    Text(currentEx.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                }
            } else {
                Text(editingSetInfo != nil ? "Edit Set" : (editingRoundIndex != nil ? "Edit Round" : "Log Set"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .padding(.top, 28)
            }

            // Progress dots for superset
            if isSupersetModal, let group = supersetGroup {
                HStack(spacing: 6) {
                    ForEach(0..<group.exercises.count, id: \.self) { i in
                        Circle()
                            .fill(i <= supersetStepIndex ? purpleAccent : Color.gymBroNeutral200)
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // Input fields
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WEIGHT (kg)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gymBroNeutral400)

                    if addSetIsBodyweight {
                        Text("BW")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.gymBroPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.gymBroPrimary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gymBroPrimary.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        TextField("0", text: $addSetWeight)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.gymBroNeutral900)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .frame(height: 52)
                            .background(Color.gymBroNeutral100)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gymBroNeutral200, lineWidth: 1)
                            )
                            .simultaneousGesture(TapGesture().onEnded { addSetWeight = "" })
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("REPS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gymBroNeutral400)

                    TextField("0", text: $addSetReps)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(height: 52)
                        .background(Color.gymBroNeutral100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gymBroNeutral200, lineWidth: 1)
                        )
                        .simultaneousGesture(TapGesture().onEnded { addSetReps = "" })
                }
            }

            // Bodyweight checkbox — lives below the inputs so it reads as a
            // modifier on the weight field rather than a separate concept.
            Button {
                addSetIsBodyweight.toggle()
                if addSetIsBodyweight { addSetWeight = "" }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: addSetIsBodyweight ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(addSetIsBodyweight ? .gymBroPrimary : .gymBroNeutral400)
                    Text("Use bodyweight")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Action button
            Button {
                submitNewSet()
            } label: {
                HStack(spacing: 8) {
                    if isSupersetModal && !isLastSupersetStep {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                        Text("Next Exercise")
                            .font(.system(size: 17, weight: .bold))
                    } else if editingSetInfo != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Update Set")
                            .font(.system(size: 17, weight: .bold))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Complete Set")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isSupersetModal && !isLastSupersetStep
                    ? LinearGradient(colors: [purpleAccent, Color(hex: "6366F1")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [greenAccent, Color(hex: "28A87A")], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (isSupersetModal && !isLastSupersetStep ? purpleAccent : greenAccent).opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!addSetIsBodyweight && addSetWeight.isEmpty && addSetReps.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Submit New Set

    private func submitNewSet() {
        let isBW = addSetIsBodyweight
        let weight: Double? = isBW ? nil : Double(addSetWeight.replacingOccurrences(of: ",", with: "."))
        let reps = Int(addSetReps) ?? 0

        // Edit existing set — if the set was still planned (not yet completed),
        // saving the popup also marks it done. Editing a completed set just
        // updates values in place without flipping any state.
        if let editing = editingSetInfo {
            let wasCompleted = viewModel.exercises
                .first(where: { $0.id == editing.exerciseId })?
                .sets.first(where: { $0.id == editing.setId })?
                .isCompleted ?? false
            Task {
                if wasCompleted {
                    await viewModel.updateSet(
                        exerciseId: editing.exerciseId,
                        setId: editing.setId,
                        weight: weight,
                        weightUnit: nil,
                        reps: reps,
                        isCompleted: nil,
                        isBodyweight: isBW
                    )
                } else {
                    await viewModel.completeSet(
                        exerciseId: editing.exerciseId,
                        setId: editing.setId,
                        weight: weight,
                        reps: reps,
                        isBodyweight: isBW
                    )
                    sessionManager.startRestTimer()
                }
            }
            showAddSetSheet = false
            editingSetInfo = nil
            return
        }

        if isSupersetModal {
            // Store entry for current exercise
            if let currentEx = currentSupersetExercise {
                supersetSetEntries.append((exerciseId: currentEx.id, weight: weight, reps: reps, isBodyweight: isBW))
            }

            if isLastSupersetStep {
                if let editingRound = editingRoundIndex {
                    // Update existing round
                    for entry in supersetSetEntries {
                        if let group = supersetGroup,
                           let ex = group.exercises.first(where: { $0.id == entry.exerciseId }),
                           editingRound < ex.sets.count {
                            Task {
                                await viewModel.updateSet(
                                    exerciseId: entry.exerciseId,
                                    setId: ex.sets[editingRound].id,
                                    weight: entry.weight,
                                    weightUnit: nil,
                                    reps: entry.reps,
                                    isCompleted: nil,
                                    isBodyweight: entry.isBodyweight
                                )
                            }
                        }
                    }
                    editingRoundIndex = nil
                } else {
                    // Add new round — log new sets
                    for entry in supersetSetEntries {
                        Task {
                            await viewModel.logSet(
                                exerciseId: entry.exerciseId,
                                weight: entry.weight,
                                reps: entry.reps,
                                isBodyweight: entry.isBodyweight
                            )
                        }
                    }
                }
                showAddSetSheet = false
                supersetSetEntries = []
                sessionManager.startRestTimer()
            } else {
                // Advance to next exercise
                supersetStepIndex += 1
                // Pre-fill with existing data when editing a round; otherwise
                // default the bodyweight toggle from the next exercise's equipment.
                if let editingRound = editingRoundIndex,
                   let group = supersetGroup,
                   supersetStepIndex < group.exercises.count {
                    let nextEx = group.exercises[supersetStepIndex]
                    if editingRound < nextEx.sets.count {
                        let nextSet = nextEx.sets[editingRound]
                        addSetWeight = nextSet.weight.map { $0.formattedWeight } ?? ""
                        addSetReps = nextSet.reps.map { "\($0)" } ?? ""
                        addSetIsBodyweight = nextSet.isBodyweight
                    } else {
                        addSetWeight = ""
                        addSetReps = ""
                        addSetIsBodyweight = nextEx.equipment == "Bodyweight"
                    }
                } else if let group = supersetGroup, supersetStepIndex < group.exercises.count {
                    let nextEx = group.exercises[supersetStepIndex]
                    addSetWeight = ""
                    addSetReps = ""
                    addSetIsBodyweight = nextEx.equipment == "Bodyweight"
                } else {
                    addSetWeight = ""
                    addSetReps = ""
                }
            }
        } else {
            // Individual exercise
            if let exercise = exercise {
                Task {
                    await viewModel.logSet(
                        exerciseId: exercise.id,
                        weight: weight,
                        reps: reps,
                        isBodyweight: isBW
                    )
                }
            }
            showAddSetSheet = false
            sessionManager.startRestTimer()
        }
    }

    private func restTimerBar(_ remaining: Int) -> some View {
        let minutes = remaining / 60
        let seconds = remaining % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)

        return HStack {
            // Timer icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("REST TIME")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.8))
                Text(timeString)
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }

            Spacer()

            // +30s button
            Button {
                sessionManager.addRestTime(30)
            } label: {
                Text("+30s")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Skip button
            Button {
                sessionManager.skipRestTimer()
            } label: {
                Text("Skip")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(purpleAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [purpleAccent, Color(hex: "6366F1")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: purpleAccent.opacity(0.4), radius: 16, y: 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Load Previous Data

    private func loadPreviousData() async {
        if let exercise = exercise, let libId = exercise.libraryExerciseId {
            let sessions = await viewModel.loadPreviousSets(for: libId)
            previousSessions[exercise.id] = sessions
        } else if let group = supersetGroup {
            for ex in group.exercises {
                if let libId = ex.libraryExerciseId {
                    let sessions = await viewModel.loadPreviousSets(for: libId)
                    previousSessions[ex.id] = sessions
                }
            }
        }
    }
}
