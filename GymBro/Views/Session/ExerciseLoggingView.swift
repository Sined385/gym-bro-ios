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

    // Cross-cluster state retained on the orchestrator.
    @State private var previousSessions: [String: [PreviousSessionEntry]] = [:]
    @State private var showAddSetSheet: Bool = false
    @State private var addSetWeight: String = ""
    @State private var addSetReps: String = ""
    @State private var addSetIsBodyweight: Bool = false
    @State private var editingSetInfo: (exerciseId: String, setId: String)?
    @State private var editingRoundIndex: Int? = nil
    @State private var detailTab: DetailTab = .workouts

    // Superset modal coordination state — shared between SupersetSection
    // (which initializes them in Add Round / Edit Round) and AddSetModal
    // (which mutates them during step-through). Lifted to the parent so
    // both surfaces can read+write a single source of truth.
    @State private var supersetStepIndex: Int = 0
    @State private var supersetSetEntries: [(exerciseId: String, weight: Double?, reps: Int, isBodyweight: Bool)] = []

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

    private var isSupersetModal: Bool { supersetGroup != nil }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                SessionHeader(
                    isSuperset: isSuperset,
                    exerciseIndex: exerciseIndex,
                    libraryExerciseId: exercise?.libraryExerciseId,
                    onBack: { dismiss() }
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isSuperset, let group = supersetGroup {
                            SupersetSection(
                                viewModel: viewModel,
                                group: group,
                                addSetWeight: $addSetWeight,
                                addSetReps: $addSetReps,
                                addSetIsBodyweight: $addSetIsBodyweight,
                                editingSetInfo: $editingSetInfo,
                                editingRoundIndex: $editingRoundIndex,
                                showAddSetSheet: $showAddSetSheet,
                                supersetStepIndex: $supersetStepIndex,
                                supersetSetEntries: $supersetSetEntries
                            )
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
                RestTimerBar(remaining: remaining, onTapBar: {
                    // Jump to the exercise whose set was logged most recently,
                    // unless we're already there. Lets you rest from anywhere
                    // and tap back to keep logging.
                    if let lastId = sessionManager.lastExecutedExerciseId,
                       lastId != exerciseId {
                        onSwitchToExercise?(lastId)
                    }
                })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                NextExercisePeekCard(
                    viewModel: viewModel,
                    exerciseId: exerciseId,
                    supersetGroupId: supersetGroupId,
                    onSwitchToExercise: onSwitchToExercise,
                    onSwitchToSuperset: onSwitchToSuperset,
                    onEndWorkout: onEndWorkout
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: sessionManager.restTimeRemaining)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddSetSheet) {
            editingSetInfo = nil
        } content: {
            AddSetModal(
                viewModel: viewModel,
                exercise: exercise,
                supersetGroup: supersetGroup,
                addSetWeight: $addSetWeight,
                addSetReps: $addSetReps,
                addSetIsBodyweight: $addSetIsBodyweight,
                editingSetInfo: $editingSetInfo,
                editingRoundIndex: $editingRoundIndex,
                showAddSetSheet: $showAddSetSheet,
                supersetStepIndex: $supersetStepIndex,
                supersetSetEntries: $supersetSetEntries
            )
            .presentationDetents([.height(isSupersetModal ? 360 : 280)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        // Keyed on the current target: switching exercises via the peek card
        // does `replaceTop(.exerciseLogging(newId))`, which reuses THIS view
        // (same nav route case) with a new id rather than pushing a fresh one.
        // A plain `.task` only fires once per view identity, so without the id
        // the next exercise's history would never load. `.task(id:)` re-runs
        // each time the id changes.
        .task(id: loadDataKey) {
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
        // Switching via the "Up Next" peek card reuses THIS view with a new
        // id (see `.task(id:)` above), so `.onAppear` never re-fires. `.task(id:)`
        // has also proven unreliable at re-triggering on the reused destination,
        // so drive BOTH the Watch pin and the previous-sets reload from an
        // explicit onChange, which fires reliably when the value changes.
        .onChange(of: loadDataKey) {
            sessionManager.setPhoneActiveExercise(activeExerciseIdForWatch)
            Task { await loadPreviousData() }
        }
        .analyticsScreen("ExerciseLogging")
    }

    /// Identity for the previous-sets load. Changes whenever the view is
    /// reused for a different exercise/superset (see `.task(id:)` above).
    private var loadDataKey: String { exerciseId ?? supersetGroupId ?? "" }

    /// What to pin on the Watch for this view: the individual exercise id, or
    /// the currently-shown step of a superset.
    private var activeExerciseIdForWatch: String? {
        if let exerciseId { return exerciseId }
        if let group = supersetGroup, supersetStepIndex < group.exercises.count {
            return group.exercises[supersetStepIndex].id
        }
        return nil
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
                ExerciseImageCarousel(imageURLs: imageURLs)
            }

            // Today / Stats segmented control
            DetailTabPicker(selection: $detailTab)

            // Tab content
            if detailTab == .workouts {
                if !readOnly {
                    LiveComparisonCard(viewModel: viewModel, exercise: exercise, lastSets: lastSessionSets(for: exercise.id))
                    todayCard(for: exercise)
                }

                if let sessions = previousSessions[exercise.id], !sessions.isEmpty {
                    ExerciseHistorySection(
                        viewModel: viewModel,
                        sessions: sessions,
                        exercise: exercise,
                        readOnly: readOnly,
                        addSetWeight: $addSetWeight,
                        addSetReps: $addSetReps,
                        addSetIsBodyweight: $addSetIsBodyweight,
                        editingSetInfo: $editingSetInfo,
                        editingRoundIndex: $editingRoundIndex,
                        showAddSetSheet: $showAddSetSheet
                    )
                }
            } else {
                ExercisePerformanceView(
                    exercise: exercise,
                    previousSessions: previousSessions[exercise.id] ?? []
                )
            }
        }
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

            // Strength: set rows + Add Set button. Cardio exercises never
            // reach this screen — SessionFlowContainer forks them into
            // CardioWorkoutView (muscle_group == "Cardio").
            SetLoggingRows(
                viewModel: viewModel,
                exercise: exercise,
                lastSets: lastSets,
                addSetWeight: $addSetWeight,
                addSetReps: $addSetReps,
                addSetIsBodyweight: $addSetIsBodyweight,
                editingSetInfo: $editingSetInfo,
                showAddSetSheet: $showAddSetSheet
            )
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
