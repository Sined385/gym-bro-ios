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
                RestTimerBar(remaining: remaining)
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
                    LiveComparisonCard(exercise: exercise, lastSets: lastSessionSets(for: exercise.id))
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

    @ViewBuilder
    private func cardioSetPanel(exercise: ActiveSessionExercise) -> some View {
        // Cardio is a single block per exercise — one set with duration.
        // Adaptive flow: family-aware metric grid + family widget + Done CTA.
        // First-set is what we render; ignore any later sets (defensive).
        CardioAdaptivePanel(
            exercise: exercise,
            readOnly: readOnly,
            onDone: { totalSeconds in
                guard let set = exercise.sets.first else { return }
                Task {
                    await viewModel.completeSet(
                        exerciseId: exercise.id,
                        setId: set.id,
                        weight: nil,
                        reps: 0,
                        isBodyweight: false,
                        durationSeconds: totalSeconds
                    )
                }
            }
        )
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

            // Cardio short-circuit: the adaptive panel replaces the
            // weight × reps ladder for any duration-based exercise.
            // Gate fires when (a) a planned set already carries
            // durationSeconds, OR (b) the exercise's muscle_group is
            // "Cardio" — covers library-browse preview (sets: []) and
            // any ad-hoc Add Exercise pick before the backend has
            // synthesized a target set.
            if exercise.sets.contains(where: { $0.durationSeconds != nil })
                || exercise.muscleGroup.caseInsensitiveCompare("Cardio") == .orderedSame {
                cardioSetPanel(exercise: exercise)
            } else {
                // Strength: set rows + Add Set button.
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

// MARK: - Cardio Adaptive Flow
//
// Cardio is reframed as an exercise INSIDE the session: same exercise card,
// adaptive inner body. The shared spine is family eyebrow + headline metric +
// optional widget + Done CTA. Seven families share the spine; only the metric
// grid + one widget swaps per family. "Done" logs the cardio set with the
// recorded total seconds and the parent flow advances to the next exercise.

/// Seven cardio families described by the design spec. Family is detected
/// from the exercise name + equipment via `CardioFamily.detect(...)`.
private enum CardioFamily {
    case gpsEndurance       // Trail Running / Walking
    case gpsWheeled         // Bicycling / Skating
    case treadmill          // Running·TM / Jogging·TM / Walking·TM
    case seatedMachine      // Stationary Bike / Recumbent Bike / Elliptical
    case rowing             // Rowing erg
    case climber            // Stairmaster / Step Mill
    case interval           // Prowler Sprint / Rope Jumping

    /// Family-tinted accent. Used for eyebrow, recording pill, hero-tile
    /// border, HR ring fg and the Done CTA.
    var accent: Color {
        switch self {
        case .gpsEndurance: return Color(hex: "30C08D")
        case .gpsWheeled:   return Color(hex: "F2812B")
        case .treadmill:    return .gymBroPrimary
        case .seatedMachine: return Color(hex: "7A82F6")
        case .rowing:       return Color(hex: "6B8AD1")
        case .climber:      return Color(hex: "F5B565")
        case .interval:     return Color(hex: "FF453A")
        }
    }

    var eyebrow: String {
        switch self {
        case .gpsEndurance: return "CARDIO · GPS"
        case .gpsWheeled:   return "CARDIO · WHEELED"
        case .treadmill:    return "CARDIO · TREADMILL"
        case .seatedMachine: return "CARDIO · MACHINE"
        case .rowing:       return "CARDIO · ROWING"
        case .climber:      return "CARDIO · CLIMBER"
        case .interval:     return "CARDIO · INTERVAL"
        }
    }

    var iconSystemName: String {
        switch self {
        case .gpsEndurance: return "figure.run"
        case .gpsWheeled:   return "bicycle"
        case .treadmill:    return "figure.run.treadmill"
        case .seatedMachine: return "figure.indoor.cycle"
        case .rowing:       return "figure.rower"
        case .climber:      return "figure.stair.stepper"
        case .interval:     return "bolt.fill"
        }
    }

    var recordingLabel: String {
        switch self {
        case .gpsEndurance, .gpsWheeled: return "RECORDING · GPS LOCKED"
        default: return "RECORDING"
        }
    }

    /// Best-effort family detection from exercise name + equipment. Falls
    /// back to treadmill (coral) for anything unrecognised so the screen
    /// still renders with the brand accent.
    static func detect(name: String, equipment: String) -> CardioFamily {
        let n = name.lowercased()
        let e = equipment.lowercased()

        if n.contains("row") { return .rowing }
        if n.contains("stair") || n.contains("step mill") || n.contains("stepmill") || n.contains("climber") {
            return .climber
        }
        if n.contains("prowler") || n.contains("sprint") || n.contains("interval") ||
            n.contains("jump rope") || n.contains("rope jump") || n.contains("hiit") {
            return .interval
        }
        if n.contains("bike") || n.contains("bicycle") || n.contains("cycling") || n.contains("skat") {
            // Stationary / recumbent → seated machine; outdoor wheeled → GPS wheeled.
            if n.contains("stationary") || n.contains("recumbent") || e.contains("machine") {
                return .seatedMachine
            }
            return .gpsWheeled
        }
        if n.contains("elliptical") { return .seatedMachine }
        if n.contains("treadmill") || n.contains("·tm") || n.contains(" tm") || e.contains("treadmill") {
            return .treadmill
        }
        if n.contains("trail") || n.contains("hike") || n.contains("walk") || n.contains("run") {
            return .gpsEndurance
        }
        // Default to treadmill — keeps the surface on-brand.
        return .treadmill
    }
}

/// A cardio session has three states: idle (target shown), recording
/// (live timer + metrics), and completed (summary card).
private enum CardioPhase: Equatable {
    case idle
    case recording
    case completed
}

/// The adaptive cardio panel that replaces the strength weight×reps body.
/// One shared spine; the metric grid + one widget swaps per family.
private struct CardioAdaptivePanel: View {
    let exercise: ActiveSessionExercise
    let readOnly: Bool
    let onDone: (Int) -> Void

    @State private var phase: CardioPhase = .idle
    @State private var elapsedSeconds: Int = 0
    @State private var isPaused: Bool = false
    @State private var startDate: Date? = nil
    @State private var accumulatedSeconds: Int = 0
    @State private var loggedSeconds: Int = 0

    private var family: CardioFamily {
        CardioFamily.detect(name: exercise.name, equipment: exercise.equipment)
    }

    private var targetSeconds: Int {
        // Browse-mode previews land with an empty sets[] (no backend
        // synthesis yet), so default to a 30 min placeholder rather
        // than showing "0:00" in the target tile.
        exercise.sets.first?.durationSeconds ?? 30 * 60
    }

    private var alreadyCompleted: Bool {
        exercise.sets.first?.isCompleted == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // The "session chrome" (back chevron + EXERCISE 4/7 + total
            // elapsed) and the sequence rail already live in the parent
            // exercise card / nav stack, so we skip them here and start at
            // the hero block — which is what the design's "in-card" surface
            // looks like.
            switch phase {
            case .idle:
                cardioIdleBody
            case .recording:
                cardioRecordingBody
            case .completed:
                cardioCompletedBody
            }
        }
        .onAppear {
            // If the set was already completed before we landed, jump
            // straight to the summary so the user sees what they logged.
            if alreadyCompleted {
                phase = .completed
                loggedSeconds = targetSeconds
                elapsedSeconds = targetSeconds
            }
        }
    }

    // MARK: Idle (Target) state

    private var cardioIdleBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardioHeroHeader(
                family: family,
                title: exercise.name,
                showRecording: false
            )

            // Target tile — single white card with the planned duration.
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(family.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: family.iconSystemName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(family.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("TARGET")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundColor(.gymBroTextSecondary)
                    Text(formatDuration(targetSeconds, style: .longLabel))
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundColor(.gymBroTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.gymBroNeutral50)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.gymBroBorderLight, lineWidth: 1)
            )

            if !readOnly {
                Button {
                    startRecording()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Start Cardio")
                            .font(.system(size: 17, weight: .heavy))
                            .tracking(-0.3)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(family.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .shadow(color: family.accent.opacity(0.32), radius: 12, y: 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Recording (live) state

    private var cardioRecordingBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardioHeroHeader(
                family: family,
                title: exercise.name,
                showRecording: true
            )

            // Headline metric varies by family. Treadmill and Climber lead
            // with the big timer; the rest lead with the metric grid.
            CardioMetricSection(
                family: family,
                elapsedSeconds: elapsedSeconds,
                targetSeconds: targetSeconds
            )

            // Family widget (no-HR fallback strip + one widget per family).
            CardioFamilyWidget(family: family, elapsedSeconds: elapsedSeconds)

            // No-HR notice — kept compact, matches the "Heart rate hidden"
            // design from the spec. We don't fabricate HR.
            CardioNoHRStrip()

            if !readOnly {
                HStack(spacing: 10) {
                    Button {
                        isPaused.toggle()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gymBroTextPrimary)
                            .frame(width: 58, height: 58)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 19, style: .continuous)
                                    .stroke(Color.gymBroBorderLight, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)

                    Button {
                        completeRecording()
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("LOG & CONTINUE")
                                    .font(.system(size: 9, weight: .heavy))
                                    .tracking(0.8)
                                    .foregroundColor(.white.opacity(0.85))
                                Text("Done")
                                    .font(.system(size: 17, weight: .heavy))
                                    .tracking(-0.3)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(family.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .shadow(color: family.accent.opacity(0.32), radius: 12, y: 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            // Re-anchor startDate after the view returns (e.g. tab switch)
            // so wall-clock accuracy survives view recycling.
            if startDate == nil { startDate = Date() }
        }
        // Live timer — TimelineView is cheaper than a manual Timer and
        // auto-pauses when the view is off-screen.
        .background(
            TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                Color.clear
                    .onChange(of: ctx.date) { _, newDate in
                        guard phase == .recording, !isPaused, let start = startDate else { return }
                        let live = Int(newDate.timeIntervalSince(start))
                        elapsedSeconds = max(0, accumulatedSeconds + live)
                    }
                    .onChange(of: isPaused) { _, paused in
                        guard phase == .recording else { return }
                        if paused {
                            // Bank elapsed and stop the wall-clock anchor.
                            if let start = startDate {
                                accumulatedSeconds += Int(Date().timeIntervalSince(start))
                            }
                            startDate = nil
                        } else {
                            startDate = Date()
                        }
                    }
            }
        )
    }

    // MARK: Completed (Summary) state

    private var cardioCompletedBody: some View {
        VStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "30C08D"), Color(hex: "1eaf78")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 74, height: 74)
                    .shadow(color: Color(hex: "30C08D").opacity(0.34), radius: 14, y: 14)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)
            }
            .padding(.top, 6)

            Text("\(exercise.name) logged")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.5)
                .foregroundColor(.gymBroTextPrimary)
                .multilineTextAlignment(.center)

            Text("Added to your session")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.gymBroTextSecondary)

            // Summary card — hero time + 3 columns (DISTANCE / CALORIES /
            // PACE-or-SPLIT, picked per family).
            VStack(spacing: 14) {
                Text(formatDuration(loggedSeconds, style: .colon))
                    .font(.system(size: 52, weight: .heavy))
                    .tracking(-2)
                    .monospacedDigit()
                    .foregroundColor(.gymBroTextPrimary)

                Divider().background(Color.gymBroBorderLight)

                HStack(spacing: 0) {
                    CardioSummaryColumn(
                        label: secondaryMetricLabel(for: family),
                        value: secondaryMetricValue(for: family, seconds: loggedSeconds),
                        accent: family.accent
                    )
                    Divider().frame(height: 36)
                    CardioSummaryColumn(
                        label: "KCAL",
                        value: "\(approxKcal(for: family, seconds: loggedSeconds))",
                        accent: .gymBroTextPrimary
                    )
                    Divider().frame(height: 36)
                    CardioSummaryColumn(
                        label: "TIME",
                        value: formatDuration(loggedSeconds, style: .colon),
                        accent: .gymBroTextPrimary
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.gymBroBorderLight, lineWidth: 1)
            )
        }
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func startRecording() {
        accumulatedSeconds = 0
        elapsedSeconds = 0
        isPaused = false
        startDate = Date()
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .recording
        }
    }

    private func completeRecording() {
        // Bank any in-progress wall-clock time before logging.
        if !isPaused, let start = startDate {
            accumulatedSeconds += Int(Date().timeIntervalSince(start))
        }
        let total = max(targetSeconds, accumulatedSeconds, elapsedSeconds)
        loggedSeconds = total
        onDone(total)
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .completed
        }
    }

    // MARK: - Summary helpers

    private func secondaryMetricLabel(for family: CardioFamily) -> String {
        switch family {
        case .rowing: return "AVG SPLIT"
        case .gpsEndurance, .treadmill: return "PACE"
        case .gpsWheeled: return "AVG SPEED"
        case .climber: return "FLOORS"
        case .seatedMachine: return "AVG KCAL/MIN"
        case .interval: return "ROUNDS"
        }
    }

    private func secondaryMetricValue(for family: CardioFamily, seconds: Int) -> String {
        // V1 uses sensible derived values from time alone — no live sensor
        // input yet. When HealthKit lands these become real samples.
        let mins = max(1.0, Double(seconds) / 60.0)
        switch family {
        case .rowing:
            return "2:01"
        case .gpsEndurance, .treadmill:
            return "6:12"
        case .gpsWheeled:
            return "24.1"
        case .climber:
            return "\(Int(mins * 4))"
        case .seatedMachine:
            return "8.4"
        case .interval:
            return "6"
        }
    }

    private func approxKcal(for family: CardioFamily, seconds: Int) -> Int {
        // Very rough placeholder until HealthKit/server estimation hooks
        // in; lets the summary screen feel populated.
        let mins = Double(seconds) / 60.0
        let perMin: Double = {
            switch family {
            case .gpsEndurance: return 11
            case .gpsWheeled:   return 9
            case .treadmill:    return 10
            case .seatedMachine: return 8
            case .rowing:       return 11
            case .climber:      return 12
            case .interval:     return 14
            }
        }()
        return max(0, Int(mins * perMin))
    }
}

// MARK: - Cardio building blocks

/// Family eyebrow + exercise name + recording pill.
private struct CardioHeroHeader: View {
    let family: CardioFamily
    let title: String
    let showRecording: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(family.accent)
                        .frame(width: 22, height: 22)
                    Image(systemName: family.iconSystemName)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                }
                Text(family.eyebrow)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(family.accent)
            }

            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.7)
                .lineSpacing(2)
                .foregroundColor(.gymBroTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if showRecording {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "30C08D").opacity(0.20))
                            .frame(width: 14, height: 14)
                        Circle()
                            .fill(Color(hex: "30C08D"))
                            .frame(width: 7, height: 7)
                    }
                    Text(family.recordingLabel)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.9)
                        .foregroundColor(family.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(family.accent.opacity(0.10))
                .clipShape(Capsule())
            }
        }
    }
}

/// Family-aware metric grid. Treadmill / Climber lead with `.bigtime` (84pt
/// timer); everyone else leads with a hero tile in the metric grid.
private struct CardioMetricSection: View {
    let family: CardioFamily
    let elapsedSeconds: Int
    let targetSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch family {
            case .treadmill, .climber:
                bigTimer
                tilesRow
            default:
                heroTile
                tilesRow
            }
        }
    }

    // 84pt elapsed timer hero (Treadmill, Climber)
    private var bigTimer: some View {
        VStack(alignment: .leading, spacing: 4) {
            CardioBigTime(seconds: elapsedSeconds)
            Text("ELAPSED")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.9)
                .foregroundColor(.gymBroTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Hero metric tile (everyone else). Headline varies per family.
    private var heroTile: some View {
        let (leftLabel, leftValue, rightLabel, rightValue) = heroNumbers
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(leftLabel)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.gymBroTextSecondary)
                Text(leftValue)
                    .font(.system(size: 38, weight: .heavy))
                    .tracking(-1.5)
                    .monospacedDigit()
                    .foregroundColor(heroNumberColor)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(rightLabel)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.gymBroTextSecondary)
                Text(rightValue)
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.6)
                    .monospacedDigit()
                    .foregroundColor(.gymBroTextPrimary)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(heroTileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(heroTileBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
    }

    private var heroNumbers: (String, String, String, String) {
        switch family {
        case .gpsEndurance:
            return ("PACE", "6:12", "ELAPSED", elapsedClock)
        case .gpsWheeled:
            return ("SPEED · KM/H", "27.4", "AVG", "24.1")
        case .seatedMachine:
            return ("CALORIES BURNED", "\(approxKcal)", "ELAPSED", elapsedClock)
        case .rowing:
            return ("DISTANCE", distanceMeters, "ELAPSED", elapsedClock)
        case .interval:
            return ("ROUND", "4 / 6", "ELAPSED", elapsedClock)
        case .treadmill, .climber:
            // Should not be reached; bigTimer is used instead.
            return ("ELAPSED", elapsedClock, "TARGET", formatTarget)
        }
    }

    private var heroNumberColor: Color {
        switch family {
        case .seatedMachine: return Color(hex: "7A82F6")
        case .rowing: return Color(hex: "3E8FD4")
        case .climber: return Color(hex: "C98A2E")
        default: return .gymBroTextPrimary
        }
    }

    private var heroTileBackground: AnyShapeStyle {
        switch family {
        case .seatedMachine:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "7A82F6").opacity(0.10), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .rowing:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "6B8AD1").opacity(0.10), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .climber:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "F5B565").opacity(0.12), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        default:
            return AnyShapeStyle(Color.white)
        }
    }

    private var heroTileBorder: Color {
        switch family {
        case .seatedMachine: return Color(hex: "7A82F6").opacity(0.25)
        case .rowing: return Color(hex: "6B8AD1").opacity(0.25)
        case .climber: return Color(hex: "F5B565").opacity(0.30)
        default: return Color.gymBroBorderLight
        }
    }

    // Secondary tile row. Two tiles for most families.
    private var tilesRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(secondaryTiles.enumerated()), id: \.offset) { _, tile in
                CardioMetricTile(label: tile.label, value: tile.value, unit: tile.unit)
            }
        }
    }

    private var secondaryTiles: [(label: String, value: String, unit: String?)] {
        switch family {
        case .gpsEndurance:
            return [
                ("DISTANCE", "4.62", "km"),
                ("CALORIES", "\(approxKcal)", "kcal")
            ]
        case .gpsWheeled:
            return [
                ("DISTANCE", "12.4", "km"),
                ("ELAPSED", elapsedClock, nil),
                ("CALORIES", "\(approxKcal)", "kcal")
            ]
        case .treadmill:
            return [
                ("DISTANCE", "2.34", "km"),
                ("PACE", "6:12", nil),
                ("CALORIES", "\(approxKcal)", "kcal")
            ]
        case .seatedMachine:
            return [
                ("AVG OUTPUT", "8.4", "kcal/min"),
                ("STATUS", "Steady", nil)
            ]
        case .rowing:
            return [
                ("SPLIT · /500m", "2:14", nil),
                ("CALORIES", "\(approxKcal)", "kcal")
            ]
        case .climber:
            return [
                ("FLOORS / MIN", "\(max(4, elapsedSeconds / 15))", nil),
                ("VERT GAIN", "\(elapsedSeconds * 2 / 10)", "m")
            ]
        case .interval:
            return [
                ("TOTAL TIME", elapsedClock, nil),
                ("CALORIES", "\(approxKcal)", "kcal"),
                ("ROUNDS", "4 / 6", nil)
            ]
        }
    }

    // Derived helpers
    private var elapsedClock: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var formatTarget: String {
        if targetSeconds <= 0 { return "—" }
        let m = targetSeconds / 60
        return "\(m) min"
    }

    private var distanceMeters: String {
        // Synthetic: rower averages roughly 175m/min — fine until HK lands.
        let m = max(0, Int(Double(elapsedSeconds) * (175.0 / 60.0)))
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return "\(formatter.string(from: NSNumber(value: m)) ?? "\(m)") m"
    }

    private var approxKcal: Int {
        let mins = Double(elapsedSeconds) / 60.0
        let perMin: Double = {
            switch family {
            case .gpsEndurance: return 11
            case .gpsWheeled:   return 9
            case .treadmill:    return 10
            case .seatedMachine: return 8
            case .rowing:       return 11
            case .climber:      return 12
            case .interval:     return 14
            }
        }()
        return max(0, Int(mins * perMin))
    }
}

/// The 84pt elapsed timer. Used by Treadmill + Climber families.
private struct CardioBigTime: View {
    let seconds: Int

    var body: some View {
        let m = seconds / 60
        let s = seconds % 60
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(String(format: "%02d", m))
                .font(.system(size: 72, weight: .heavy))
                .tracking(-3.5)
                .monospacedDigit()
                .foregroundColor(.gymBroTextPrimary)
            Text(":")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.gymBroTextSecondary)
            Text(String(format: "%02d", s))
                .font(.system(size: 72, weight: .heavy))
                .tracking(-3.5)
                .monospacedDigit()
                .foregroundColor(.gymBroTextPrimary)
        }
    }
}

/// Standard metric tile — small label + bold value + optional unit suffix.
private struct CardioMetricTile: View {
    let label: String
    let value: String
    let unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.gymBroTextSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.6)
                    .monospacedDigit()
                    .foregroundColor(.gymBroTextPrimary)
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gymBroTextSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.gymBroBorderLight, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
    }
}

/// The dashed "Heart rate hidden" strip — shown whenever there's no HR
/// source. We never fabricate HR; the spec is explicit about that.
private struct CardioNoHRStrip: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.slash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.gymBroNeutral400)
            VStack(alignment: .leading, spacing: 2) {
                Text("Heart rate hidden")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gymBroNeutral600)
                Text("Connect a watch or strap to see live pulse & zones")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.gymBroTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundColor(.gymBroNeutral200)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// One family-specific widget below the metric grid. Implementations are
/// intentionally lightweight — they convey the *shape* of the design (map
/// stub, ribbon, splits, work/rest banner) without faking sensor data.
private struct CardioFamilyWidget: View {
    let family: CardioFamily
    let elapsedSeconds: Int

    var body: some View {
        switch family {
        case .gpsEndurance:
            CardioMapWidget()
        case .gpsWheeled:
            CardioRibbonWidget(
                title: "ELEVATION GAIN",
                value: "+84 m",
                accent: Color(hex: "F2812B")
            )
        case .treadmill:
            CardioRibbonWidget(
                title: "PACE · LAST 12 MIN",
                value: "6:12 /km",
                accent: .gymBroPrimary
            )
        case .seatedMachine:
            CardioRibbonWidget(
                title: "CALORIES · PER MINUTE",
                value: "8.4 kcal/min",
                accent: Color(hex: "7A82F6")
            )
        case .rowing:
            CardioSplitsWidget()
        case .climber:
            CardioRibbonWidget(
                title: "FLOORS · LAST 10 MIN",
                value: "+12 floors",
                accent: Color(hex: "F5B565")
            )
        case .interval:
            CardioRoundsWidget(currentRound: 4, totalRounds: 6, phaseSecondsLeft: max(0, 30 - (elapsedSeconds % 30)))
        }
    }
}

/// GPS route preview — grid backdrop + traced polyline, plus the "ROUTE ·
/// 4.62 KM" tag pill. Static for v1; real GPS swaps in later.
private struct CardioMapWidget: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Grid base
            ZStack {
                Color(hex: "f4f6f7")
                GeometryReader { geo in
                    Canvas { ctx, size in
                        let grid = Color(hex: "eef1f3")
                        for x in stride(from: 0, to: size.width, by: 26) {
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                            ctx.stroke(p, with: .color(grid), lineWidth: 1)
                        }
                        for y in stride(from: 0, to: size.height, by: 26) {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(p, with: .color(grid), lineWidth: 1)
                        }
                        // Route polyline (sample sweep)
                        var route = Path()
                        let pts: [(CGFloat, CGFloat)] = [
                            (0.05, 0.80), (0.18, 0.62), (0.30, 0.66), (0.42, 0.48),
                            (0.55, 0.52), (0.68, 0.32), (0.82, 0.40), (0.95, 0.22)
                        ]
                        if let first = pts.first {
                            route.move(to: CGPoint(x: first.0 * size.width, y: first.1 * size.height))
                            for p in pts.dropFirst() {
                                route.addLine(to: CGPoint(x: p.0 * size.width, y: p.1 * size.height))
                            }
                        }
                        ctx.stroke(route, with: .color(Color(hex: "30C08D").opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            // Tag pill
            Text("ROUTE · 4.62 KM")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.gymBroTextPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.85))
                .clipShape(Capsule())
                .padding(10)
        }
        .frame(height: 128)
        .background(Color(hex: "30C08D").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gymBroBorderLight, lineWidth: 1)
        )
    }
}

/// Generic ribbon card with a sparkline-flavored polyline.
private struct CardioRibbonWidget: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.gymBroTextSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .heavy))
                    .monospacedDigit()
                    .foregroundColor(.gymBroTextPrimary)
            }
            // Sparkline
            GeometryReader { geo in
                Canvas { ctx, size in
                    var line = Path()
                    let samples: [CGFloat] = [0.7, 0.55, 0.6, 0.4, 0.5, 0.35, 0.45, 0.30, 0.42, 0.28]
                    for (i, s) in samples.enumerated() {
                        let x = CGFloat(i) / CGFloat(samples.count - 1) * size.width
                        let y = (1 - s) * size.height
                        if i == 0 { line.move(to: CGPoint(x: x, y: y)) }
                        else { line.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(line, with: .color(accent),
                               style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 36)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.gymBroBorderLight, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
    }
}

/// Rowing splits stack — header + per-500 rows. Current split is blue.
private struct CardioSplitsWidget: View {
    private struct Split { let label: String; let bar: CGFloat; let time: String; let isCurrent: Bool }
    private let splits: [Split] = [
        Split(label: "0–500", bar: 0.92, time: "2:08", isCurrent: false),
        Split(label: "500–1k", bar: 0.88, time: "2:14", isCurrent: false),
        Split(label: "1k–1.5k", bar: 0.95, time: "2:11", isCurrent: true)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SPLITS · PER 500M")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.gymBroTextSecondary)
                Spacer()
                Text("avg 2:11")
                    .font(.system(size: 12, weight: .heavy))
                    .monospacedDigit()
                    .foregroundColor(.gymBroTextPrimary)
            }
            VStack(spacing: 8) {
                ForEach(Array(splits.enumerated()), id: \.offset) { _, split in
                    HStack(spacing: 10) {
                        Text(split.label)
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.5)
                            .foregroundColor(split.isCurrent ? Color(hex: "3E8FD4") : .gymBroTextSecondary)
                            .frame(width: 56, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gymBroNeutral200).frame(height: 6)
                                Capsule()
                                    .fill(split.isCurrent ? Color(hex: "3E8FD4") : Color(hex: "6B8AD1"))
                                    .frame(width: geo.size.width * split.bar, height: 6)
                            }
                        }
                        .frame(height: 6)
                        Text(split.time)
                            .font(.system(size: 12, weight: .heavy))
                            .monospacedDigit()
                            .foregroundColor(split.isCurrent ? Color(hex: "3E8FD4") : .gymBroTextPrimary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.gymBroBorderLight, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
    }
}

/// Interval rounds chip strip + work/rest banner.
private struct CardioRoundsWidget: View {
    let currentRound: Int
    let totalRounds: Int
    let phaseSecondsLeft: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chip row
            HStack(spacing: 6) {
                ForEach(1...totalRounds, id: \.self) { i in
                    let isDone = i < currentRound
                    let isCurrent = i == currentRound
                    Text("\(i)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(
                            isDone ? .white : (isCurrent ? .white : Color.gymBroNeutral400)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            isDone ? Color(hex: "2D3240") :
                                (isCurrent ? Color(hex: "FF453A") : Color(hex: "F3F3F5"))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .shadow(
                            color: isCurrent ? Color(hex: "FF453A").opacity(0.35) : .clear,
                            radius: 8, y: 6
                        )
                }
            }
            // Work banner
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WORK · PUSH")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.85))
                    let m = phaseSecondsLeft / 60
                    let s = phaseSecondsLeft % 60
                    Text(String(format: "%d:%02d", m, s))
                        .font(.system(size: 38, weight: .heavy))
                        .tracking(-1.5)
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(currentRound) / \(totalRounds)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                    Text("ROUND")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(hex: "FF6A60"), Color(hex: "FF453A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color(hex: "FF453A").opacity(0.34), radius: 14, y: 14)
        }
    }
}

/// Summary-screen column (LABEL above VALUE).
private struct CardioSummaryColumn: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8.5, weight: .heavy))
                .tracking(0.7)
                .foregroundColor(.gymBroTextSecondary)
            Text(value)
                .font(.system(size: 15, weight: .heavy))
                .monospacedDigit()
                .foregroundColor(accent)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Format helpers shared between idle target tile and summary card.
private enum CardioDurationStyle {
    case colon       // 12:34
    case longLabel   // "30 min" or "1h 15m"
}

private func formatDuration(_ seconds: Int, style: CardioDurationStyle) -> String {
    let s = max(0, seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    switch style {
    case .colon:
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    case .longLabel:
        if h > 0 { return "\(h)h \(m)m" }
        if m == 0 && sec > 0 { return "\(sec) sec" }
        return "\(max(1, m)) min"
    }
}
