//
//  SessionFlowViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import Foundation
import Combine
import SwiftUI
import HealthKit
import FirebaseAnalytics

@MainActor
final class SessionFlowViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var sessionId: String
    @Published var sessionTitle: String
    @Published var exercises: [ActiveSessionExercise] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Feedback
    @Published var effortLevel: Int = 0
    @Published var energyLevel: Int = 0
    @Published var painDiscomfort: String = ""

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let sessionManager: ActiveSessionManager
    private let healthKitService: HealthKitServiceProtocol
    private let analyticsService: AnalyticsTrackingServiceProtocol
    let subscriptionManager: SubscriptionManager
    private let completionCacheService: SessionCompletionCacheServiceProtocol
    private var repeatLastSetCancellable: AnyCancellable?

    /// When true, the instance is a read-only display container (used by the
    /// exercise library to show a single exercise inside ExerciseLoggingView
    /// without driving a real workout session). The init skips every
    /// side-effecting setup so the live session's watch callbacks and
    /// Live-Activity subscription aren't hijacked.
    let isPreviewMode: Bool

    // MARK: - Computed Properties

    var supersetGroups: [SupersetGroup] {
        // Group exercises by supersetGroupId
        var groups: [String: [ActiveSessionExercise]] = [:]
        for exercise in exercises {
            if let groupId = exercise.supersetGroupId {
                groups[groupId, default: []].append(exercise)
            }
        }
        return groups.map { SupersetGroup(id: $0.key, exercises: $0.value.sorted { ($0.supersetOrder ?? "") < ($1.supersetOrder ?? "") }) }
    }

    var standaloneExercises: [ActiveSessionExercise] {
        exercises.filter { $0.supersetGroupId == nil }
    }

    var hasExercises: Bool {
        !exercises.isEmpty
    }

    // MARK: - Next-target navigation

    enum NextWorkoutTarget: Equatable {
        case exercise(id: String, label: String)
        case superset(groupId: String, label: String)

        var label: String {
            switch self {
            case .exercise(_, let label), .superset(_, let label): return label
            }
        }
    }

    /// Walks standalone exercises + supersets in step_number order and
    /// returns the slot after the current one. A superset's step number
    /// is the min step among its members, so a superset only appears
    /// once in the sequence.
    func nextWorkoutTarget(afterExerciseId: String? = nil, afterSupersetGroupId: String? = nil) -> NextWorkoutTarget? {
        struct Slot {
            let target: NextWorkoutTarget
            let stepNumber: Int
            let matchesExerciseId: String?
            let matchesGroupId: String?
        }

        var slots: [Slot] = []
        for ex in standaloneExercises {
            slots.append(Slot(
                target: .exercise(id: ex.id, label: ex.name),
                stepNumber: ex.stepNumber,
                matchesExerciseId: ex.id,
                matchesGroupId: nil
            ))
        }
        for group in supersetGroups {
            let firstStep = group.exercises.map { $0.stepNumber }.min() ?? Int.max
            let label = group.exercises.first?.name ?? "Superset"
            slots.append(Slot(
                target: .superset(groupId: group.id, label: label),
                stepNumber: firstStep,
                matchesExerciseId: nil,
                matchesGroupId: group.id
            ))
        }
        slots.sort { $0.stepNumber < $1.stepNumber }

        guard let currentIdx = slots.firstIndex(where: { slot in
            if let exId = afterExerciseId { return slot.matchesExerciseId == exId }
            if let gid = afterSupersetGroupId { return slot.matchesGroupId == gid }
            return false
        }), currentIdx + 1 < slots.count else { return nil }

        return slots[currentIdx + 1].target
    }

    // MARK: - Accent Colors

    private static let accentColors = ["#E86A75", "#30C08D", "#7A82F6", "#F5A623"]

    private func nextAccentColor() -> String {
        let index = exercises.count % Self.accentColors.count
        return Self.accentColors[index]
    }

    // MARK: - Initialization

    init(sessionId: String, sessionTitle: String, networkService: NetworkServiceProtocol, sessionManager: ActiveSessionManager, healthKitService: HealthKitServiceProtocol, analyticsService: AnalyticsTrackingServiceProtocol, subscriptionManager: SubscriptionManager = DependencyContainer.shared.resolve(SubscriptionManager.self), completionCacheService: SessionCompletionCacheServiceProtocol = DependencyContainer.shared.resolve(SessionCompletionCacheServiceProtocol.self), initialExercises: [DashboardExercise] = [], restoredExercises: [ActiveSessionExercise]? = nil, restoredFeedback: (effort: Int, energy: Int, pain: String)? = nil, isPreviewMode: Bool = false) {
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.networkService = networkService
        self.sessionManager = sessionManager
        self.healthKitService = healthKitService
        self.analyticsService = analyticsService
        self.subscriptionManager = subscriptionManager
        self.completionCacheService = completionCacheService
        self.isPreviewMode = isPreviewMode

        if let restored = restoredExercises {
            _exercises = Published(wrappedValue: restored)
            if let feedback = restoredFeedback {
                _effortLevel = Published(wrappedValue: feedback.effort)
                _energyLevel = Published(wrappedValue: feedback.energy)
                _painDiscomfort = Published(wrappedValue: feedback.pain)
            }
            if !isPreviewMode {
                // Clear restored data from session manager
                sessionManager.restoredExercises = nil
                sessionManager.restoredFeedback = nil
                // Sync exercises back to session manager for persistence
                Task { [weak self] in
                    self?.notifySessionChanged()
                }
            }
        } else {
            // Convert DashboardExercises to ActiveSessionExercises.
            // When the API supplied per-set targets (Coach progressive
            // overload path), use those verbatim so the user sees the
            // actual weight × rep ladder Coach proposed. Otherwise
            // fall back to expanding sets_display into placeholders
            // anchored at the suggested weight.
            let converted = initialExercises.map { dashEx in
                let (targetSets, targetReps) = Self.parseSetsDisplay(dashEx.setsDisplay)
                let sets: [ActiveSet]
                if let provided = dashEx.sets, !provided.isEmpty {
                    sets = provided.map { ps in
                        ActiveSet(
                            id: UUID().uuidString,
                            setNumber: ps.setNumber,
                            weight: ps.weight,
                            weightUnit: ps.weightUnit ?? "kg",
                            reps: ps.reps,
                            isCompleted: false,
                            isBodyweight: ps.isBodyweight ?? false,
                            durationSeconds: ps.durationSeconds,
                            distanceMeters: ps.distanceMeters,
                            targetSpeedKmh: ps.targetSpeedKmh,
                        )
                    }
                } else {
                    sets = (1...max(targetSets, 1)).map { setNum in
                        ActiveSet(
                            id: UUID().uuidString,
                            setNumber: setNum,
                            weight: dashEx.suggestedWeight,
                            weightUnit: "kg",
                            reps: targetReps > 0 ? targetReps : nil,
                            isCompleted: false
                        )
                    }
                }
                return ActiveSessionExercise(
                    id: dashEx.id,
                    libraryExerciseId: dashEx.libraryExerciseId,
                    name: dashEx.name,
                    muscleGroup: dashEx.muscleGroup ?? "",
                    equipment: dashEx.equipment ?? "",
                    accentColor: dashEx.accentColor,
                    stepNumber: dashEx.stepNumber,
                    sets: sets,
                    supersetGroupId: nil,
                    supersetOrder: nil,
                    targetSets: targetSets,
                    targetReps: targetReps,
                    imageUrl: dashEx.imageUrl,
                    externalId: dashEx.externalId
                )
            }
            if !converted.isEmpty {
                _exercises = Published(wrappedValue: converted)
            }

            // Save initial state if we have exercises
            if !initialExercises.isEmpty && !isPreviewMode {
                Task { [weak self] in
                    self?.notifySessionChanged()
                }
            }
        }

        // Live-Activity + Watch wiring belong to the real active session
        // only. A preview-mode instance is constructed transiently for the
        // library's exercise detail and must not hijack the live session's
        // callbacks or subscriptions.
        if !isPreviewMode {
            // Observe repeat-last-set requests from Live Activity
            repeatLastSetCancellable = sessionManager.$repeatLastSetRequested
                .dropFirst()
                .filter { $0 }
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.handleRepeatLastSet()
                    }
                }

            // Handle set completions from Watch
            sessionManager.onWatchSetCompletion = { [weak self] exerciseId, setId, weight, reps in
                Task { @MainActor [weak self] in
                    await self?.completeSetFromWatch(exerciseId: exerciseId, setId: setId, weight: weight, reps: reps)
                }
            }
        }
    }

    /// Parses "4 × 10" to extract sets count (4) and reps (10)
    /// Handles various AI formats: "3 × 10", "3x10", "3X10", "3 × 10-12", "3 sets × 10 reps"
    private static func parseSetsDisplay(_ setsDisplay: String) -> (sets: Int, reps: Int) {
        let cleaned = setsDisplay
            .replacingOccurrences(of: "×", with: "x")
            .lowercased()
        let parts = cleaned.split(separator: "x").map { $0.trimmingCharacters(in: .whitespaces) }
        let sets = parts.first.flatMap { extractLeadingInt($0) } ?? 0
        let reps = parts.count > 1 ? (extractLeadingInt(parts[1]) ?? 0) : 0
        return (sets, reps)
    }

    /// Extracts the leading integer from a string (e.g. "10-12" → 10, "3 sets" → 3)
    private static func extractLeadingInt(_ s: String) -> Int? {
        let digits = String(s.prefix(while: { $0.isNumber }))
        return digits.isEmpty ? nil : Int(digits)
    }

    // MARK: - Persistence

    private func notifySessionChanged() {
        sessionManager.saveSession(
            exercises: exercises,
            effortLevel: effortLevel,
            energyLevel: energyLevel,
            painDiscomfort: painDiscomfort
        )
    }

    /// THE single chokepoint for mutating `exercises`. Copies the array,
    /// applies `body`, then assigns the whole array back so the @Published
    /// setter fires `objectWillChange`.
    ///
    /// Why this matters: nested in-place mutation
    /// (`exercises[i].sets[j].x = y`) and `exercises.append/removeAll` go
    /// through Array's `_modify` accessor, which does NOT reliably publish.
    /// Views that hold a value-copy of an exercise (e.g. SetLoggingRows'
    /// `let exercise`) then never refresh — completed sets appeared to
    /// "lag by one" tap. Route EVERY exercises mutation through here.
    private func mutateExercises(_ body: (inout [ActiveSessionExercise]) -> Void) {
        var copy = exercises
        body(&copy)
        exercises = copy
    }

    // MARK: - Exercise Management

    func addExercise(_ item: ExerciseLibraryItem) async {
        let newExercise = ActiveSessionExercise(
            id: UUID().uuidString,
            libraryExerciseId: item.id,
            name: item.name,
            muscleGroup: item.muscleGroup,
            equipment: item.equipment,
            accentColor: nextAccentColor(),
            stepNumber: exercises.count + 1,
            sets: [],
            supersetGroupId: nil,
            supersetOrder: nil,
            targetSets: 0,
            targetReps: 0,
            imageUrl: ExerciseImageURLBuilder.thumbnailURL(for: item.externalId)?.absoluteString ?? item.images?.first,
            externalId: item.externalId,
            isFavorite: item.isFavorite
        )
        mutateExercises { $0.append(newExercise) }

        analyticsService.track("exercise_added", properties: [
            "exercise_name": item.name,
            "muscle_group": item.muscleGroup
        ])

        notifySessionChanged()
    }

    func addSuperset(_ exerciseIds: [String]) async {
        guard subscriptionManager.requireFeature(.supersets) else { return }
        // Local-only: group existing exercises into a superset
        let groupId = UUID().uuidString
        let orders = ["A", "B", "C", "D", "E"]
        mutateExercises { ex in
            for (index, exerciseId) in exerciseIds.enumerated() {
                if let idx = ex.firstIndex(where: { $0.id == exerciseId }) {
                    ex[idx].supersetGroupId = groupId
                    ex[idx].supersetOrder = index < orders.count ? orders[index] : "\(index)"
                }
            }
        }
        analyticsService.track("superset_created", properties: ["exercise_count": exerciseIds.count])
        notifySessionChanged()
    }

    func addSupersetFromLibrary(_ items: [ExerciseLibraryItem]) async {
        guard subscriptionManager.requireFeature(.supersets) else { return }
        let groupId = UUID().uuidString
        let orders = ["A", "B", "C", "D", "E"]
        mutateExercises { ex in
            for (index, item) in items.enumerated() {
                let order = index < orders.count ? orders[index] : "\(index)"
                // If exercise is already in the session, group it instead of duplicating
                if let existingIndex = ex.firstIndex(where: { $0.libraryExerciseId == item.id && $0.supersetGroupId == nil }) {
                    ex[existingIndex].supersetGroupId = groupId
                    ex[existingIndex].supersetOrder = order
                } else {
                    let newExercise = ActiveSessionExercise(
                        id: UUID().uuidString,
                        libraryExerciseId: item.id,
                        name: item.name,
                        muscleGroup: item.muscleGroup,
                        equipment: item.equipment,
                        accentColor: nextAccentColor(),
                        stepNumber: ex.count + 1,
                        sets: [],
                        supersetGroupId: groupId,
                        supersetOrder: order,
                        targetSets: 0,
                        targetReps: 0,
                        imageUrl: ExerciseImageURLBuilder.thumbnailURL(for: item.externalId)?.absoluteString ?? item.images?.first,
                        externalId: item.externalId
                    )
                    ex.append(newExercise)
                }
            }
        }
        analyticsService.track("superset_created", properties: ["exercise_count": items.count])
        notifySessionChanged()
    }

    func removeExercise(_ exerciseId: String) async {
        mutateExercises { $0.removeAll { $0.id == exerciseId } }
        notifySessionChanged()
    }

    /// Move standalone exercises to a new position. Indexes refer to the
    /// filtered standalone list — superset members stay in place.
    ///
    /// Reorder is local-only during the live session: we restamp stepNumber
    /// across all exercises and update the in-memory cache so the UI reflects
    /// the new order immediately. The server-side persist happens when the
    /// session is completed (completeSessionFull sends each exercise with
    /// its current stepNumber, so the new order rides along).
    func reorderStandaloneExercises(from source: IndexSet, to destination: Int) async {
        var standalone = exercises.filter { $0.supersetGroupId == nil }
        standalone.move(fromOffsets: source, toOffset: destination)

        var standaloneIter = standalone.makeIterator()
        var rebuilt: [ActiveSessionExercise] = []
        for ex in exercises {
            if ex.supersetGroupId == nil {
                if let next = standaloneIter.next() { rebuilt.append(next) }
            } else {
                rebuilt.append(ex)
            }
        }
        for (idx, _) in rebuilt.enumerated() {
            rebuilt[idx].stepNumber = idx + 1
        }
        exercises = rebuilt
        notifySessionChanged()
    }

    func removeSuperset(_ groupId: String) async {
        mutateExercises { $0.removeAll { $0.supersetGroupId == groupId } }
        notifySessionChanged()
    }

    // MARK: - Set Management

    func completeSet(exerciseId: String, setId: String, weight: Double?, reps: Int, isBodyweight: Bool = false, durationSeconds: Int? = nil, distanceMeters: Int? = nil) async {
        sessionManager.cancelStillThereNotification()

        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) else { return }

        let isCardio = durationSeconds != nil
        mutateExercises { ex in
            // When the user flipped the bodyweight toggle (or this is a
            // cardio set), force the stored weight to nil so display sites
            // never read a stale value.
            ex[exerciseIndex].sets[setIndex].weight = (isBodyweight || isCardio) ? nil : weight
            ex[exerciseIndex].sets[setIndex].reps = reps
            ex[exerciseIndex].sets[setIndex].isCompleted = true
            ex[exerciseIndex].sets[setIndex].isBodyweight = isBodyweight
            if isCardio {
                ex[exerciseIndex].sets[setIndex].durationSeconds = durationSeconds
                if let distanceMeters {
                    ex[exerciseIndex].sets[setIndex].distanceMeters = distanceMeters
                }
            }
        }

        notifySessionChanged()
        sessionManager.scheduleStartReminder()

        sessionManager.updateLastCompletedSet(
            exerciseName: exercises[exerciseIndex].name,
            weight: (isBodyweight || isCardio) ? nil : weight,
            weightUnit: exercises[exerciseIndex].sets[setIndex].weightUnit,
            reps: reps
        )

        Analytics.logEvent("set_logged", parameters: [
            "exercise_name": exercises[exerciseIndex].name,
            "weight": weight ?? 0,
            "reps": reps,
            "is_bodyweight": isBodyweight,
            "duration_seconds": durationSeconds ?? 0
        ] as [String: Any])
    }

    /// Record a completed cardio block (time + distance). Updates the
    /// exercise's first not-yet-completed set, or APPENDS a completed set
    /// when the exercise has none yet — ad-hoc-added cardio starts with no
    /// sets, and the old path (completeSet on `sets.first`) silently
    /// dropped the recording, so the walk saved with no duration.
    func completeCardioSet(exerciseId: String, durationSeconds: Int, distanceMeters: Int?) async {
        sessionManager.cancelStillThereNotification()
        guard let exIdx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        mutateExercises { ex in
            let targetIdx = ex[exIdx].sets.firstIndex(where: { !$0.isCompleted })
                ?? ex[exIdx].sets.indices.first
            if let setIdx = targetIdx {
                ex[exIdx].sets[setIdx].weight = nil
                ex[exIdx].sets[setIdx].reps = 0
                ex[exIdx].sets[setIdx].isBodyweight = false
                ex[exIdx].sets[setIdx].isCompleted = true
                ex[exIdx].sets[setIdx].durationSeconds = durationSeconds
                ex[exIdx].sets[setIdx].distanceMeters = distanceMeters
            } else {
                ex[exIdx].sets.append(ActiveSet(
                    id: UUID().uuidString,
                    setNumber: 1,
                    weight: nil,
                    weightUnit: "kg",
                    reps: 0,
                    isCompleted: true,
                    isBodyweight: false,
                    durationSeconds: durationSeconds,
                    distanceMeters: distanceMeters
                ))
            }
        }
        notifySessionChanged()
        sessionManager.scheduleStartReminder()
    }

    func logSet(exerciseId: String, weight: Double?, weightUnit: String = "kg", reps: Int, isBodyweight: Bool = false) async {
        sessionManager.cancelStillThereNotification()

        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        let setNumber = exercises[exerciseIndex].sets.count + 1
        let newSet = ActiveSet(
            id: UUID().uuidString,
            setNumber: setNumber,
            weight: isBodyweight ? nil : weight,
            weightUnit: weightUnit,
            reps: reps,
            isCompleted: true,
            isBodyweight: isBodyweight
        )
        mutateExercises { $0[exerciseIndex].sets.append(newSet) }

        notifySessionChanged()
        sessionManager.scheduleStartReminder()

        sessionManager.updateLastCompletedSet(
            exerciseName: exercises[exerciseIndex].name,
            weight: isBodyweight ? nil : weight,
            weightUnit: weightUnit,
            reps: reps
        )
    }

    func updateSet(exerciseId: String, setId: String, weight: Double?, weightUnit: String?, reps: Int?, isCompleted: Bool?, isBodyweight: Bool? = nil) async {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) else { return }

        mutateExercises { ex in
            if let isBodyweight { ex[exerciseIndex].sets[setIndex].isBodyweight = isBodyweight }
            // If the set is now bodyweight, clear the weight; otherwise accept the new value.
            if ex[exerciseIndex].sets[setIndex].isBodyweight {
                ex[exerciseIndex].sets[setIndex].weight = nil
            } else if let weight = weight {
                ex[exerciseIndex].sets[setIndex].weight = weight
            }
            if let weightUnit = weightUnit { ex[exerciseIndex].sets[setIndex].weightUnit = weightUnit }
            if let reps = reps { ex[exerciseIndex].sets[setIndex].reps = reps }
            if let isCompleted = isCompleted { ex[exerciseIndex].sets[setIndex].isCompleted = isCompleted }
        }
        notifySessionChanged()
    }

    func deleteSet(exerciseId: String, setId: String) async {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        mutateExercises { $0[exerciseIndex].sets.removeAll { $0.id == setId } }
        notifySessionChanged()
    }

    // MARK: - Previous Sets

    func loadPreviousSets(for libraryExerciseId: String) async -> [PreviousSessionEntry] {
        do {
            let response = try await networkService.request(
                ExerciseRouter.previousSets(exerciseId: libraryExerciseId).endpoint,
                responseType: PreviousSetsResponse.self
            )
            return response.sessions
        } catch {
            // No previous data available
            return []
        }
    }

    /// The user's body weight (kg) from their onboarding profile. Used as
    /// the calorie-estimate fallback when HealthKit has no weight sample
    /// (e.g. permission not granted, or the simulator). Returns nil when
    /// onboarding has no recorded weight.
    func loadBodyWeightKg() async -> Double? {
        struct OnboardingBodyWeight: Decodable {
            let bodyWeightKg: Double?
        }
        do {
            let response = try await networkService.request(
                OnboardingRouter.fetch.endpoint,
                responseType: OnboardingBodyWeight.self
            )
            return response.bodyWeightKg
        } catch {
            return nil
        }
    }

    /// Update the user-editable cardio targets (duration + pace) on the
    /// exercise's single cardio set, before recording starts. Persists
    /// through the session cache (and the completion payload) so the
    /// edited target survives backgrounding and reaches the server when
    /// the workout finishes. No-op once the set is completed.
    func updateCardioTargets(exerciseId: String, durationSeconds: Int?, targetSpeedKmh: Double?) {
        guard let exIdx = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIdx = exercises[exIdx].sets.firstIndex(where: { !$0.isCompleted })
                ?? exercises[exIdx].sets.indices.first else { return }
        mutateExercises { ex in
            if let durationSeconds, durationSeconds > 0 {
                ex[exIdx].sets[setIdx].durationSeconds = durationSeconds
            }
            ex[exIdx].sets[setIdx].targetSpeedKmh = targetSpeedKmh
        }
        notifySessionChanged()
    }

    // MARK: - Repeat Last Set (Live Activity)

    private func handleRepeatLastSet() {
        sessionManager.repeatLastSetRequested = false

        // Find the last completed set across all exercises
        var lastExerciseIndex: Int?
        var lastSet: ActiveSet?
        for (i, exercise) in exercises.enumerated() {
            if let completed = exercise.sets.last(where: { $0.isCompleted }) {
                lastExerciseIndex = i
                lastSet = completed
            }
        }

        guard let exerciseIndex = lastExerciseIndex, let set = lastSet else { return }
        let exercise = exercises[exerciseIndex]
        Task {
            await logSet(
                exerciseId: exercise.id,
                weight: set.weight,
                weightUnit: set.weightUnit,
                reps: set.reps ?? 0
            )
        }
    }

    // MARK: - Watch Set Completion

    func completeSetFromWatch(exerciseId: String, setId: String, weight: Double?, reps: Int) async {
        // Empty setId is the Watch's signal for "log a new set" — used
        // when Repeat Last fires on an exercise that was added mid-
        // session and has no pending template set to mark complete.
        // The phone's logSet path appends a fresh set with auto-
        // generated id. Non-empty setId follows the normal find-and-
        // complete path.
        if setId.isEmpty {
            await logSet(exerciseId: exerciseId, weight: weight, reps: reps)
        } else {
            await completeSet(exerciseId: exerciseId, setId: setId, weight: weight, reps: reps)
        }
        // Match the iPhone inline-checkmark flow — the rest timer is what
        // tells both screens (and the Watch via WCSession push) that we're
        // resting now. Without this the user just sees "set logged" and no
        // countdown on either device.
        sessionManager.startRestTimer()
    }

    // MARK: - Session Completion

    /// Cancels the in-progress session server-side. Returns `true` even on
    /// network failure so the user is never trapped in a discarded workout —
    /// the row will reconcile on the next dashboard load.
    func cancelSession() async -> Bool {
        sessionManager.stopTimer()
        sessionManager.pushWatchSessionEnded()
        isLoading = true
        do {
            try await networkService.request(
                HomeRouter.cancelSession(sessionId: sessionId).endpoint
            )
        } catch {
            print("[SessionFlow] cancelSession failed: \(error)")
        }
        analyticsService.track("workout_cancelled", properties: [
            "exercise_count": exercises.count,
            "elapsed_seconds": sessionManager.elapsedSeconds
        ] as [String: Any])
        isLoading = false
        return true
    }

    func submitFeedbackAndComplete() async -> SessionResponse? {
        sessionManager.stopTimer()
        sessionManager.pushWatchSessionEnded()
        isLoading = true
        errorMessage = nil

        let trackedDuration = max(1, sessionManager.elapsedSeconds / 60)

        // Build typed payload for cache persistence. Metadata fields
        // (title/type/aiMessage/startedAt/planDayId) let the server
        // construct the WorkoutSession row from scratch when the new
        // "store on complete" flow is in effect — /start no longer
        // pre-creates one, so the server has only what this payload
        // tells it.
        let completionPayload = SessionCompletionPayload(
            durationMinutes: trackedDuration,
            avgHeartRate: sessionManager.sessionAverageHeartRate,
            feedback: SessionFeedback(
                effortLevel: effortLevel,
                energyLevel: energyLevel,
                painDiscomfort: painDiscomfort
            ),
            exercises: exercises.map { ex in
                CompletionExercise(
                    name: ex.name,
                    muscleGroup: ex.muscleGroup,
                    stepNumber: ex.stepNumber,
                    sets: ex.sets.filter(\.isCompleted).map { set in
                        let isCardio = set.durationSeconds != nil
                        return CompletionSet(
                            setNumber: set.setNumber,
                            reps: set.reps ?? 0,
                            isCompleted: set.isCompleted,
                            weight: (set.isBodyweight || isCardio) ? nil : set.weight,
                            weightUnit: set.weightUnit,
                            isBodyweight: set.isBodyweight,
                            durationSeconds: set.durationSeconds,
                            distanceMeters: set.distanceMeters,
                            targetSpeedKmh: set.targetSpeedKmh
                        )
                    },
                    libraryExerciseId: ex.libraryExerciseId,
                    equipment: ex.equipment,
                    accentColor: ex.accentColor,
                    supersetGroupId: ex.supersetGroupId,
                    supersetOrder: ex.supersetOrder
                )
            },
            title: sessionTitle,
            type: sessionManager.sessionType,
            aiMessage: sessionManager.aiMessage,
            startedAt: sessionManager.sessionStartDate,
            planDayId: sessionManager.planDayId,
        )

        // Persist to disk BEFORE the network call so data survives app kill
        let pendingCompletion = PendingSessionCompletion(
            id: UUID(),
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            payload: completionPayload,
            createdAt: Date(),
            retryCount: 0,
            lastRetryAt: nil
        )
        completionCacheService.save(pendingCompletion)

        let payload = completionPayload.toDictionary()

        do {
            let response = try await networkService.request(
                SessionRouter.completeSessionFull(sessionId: sessionId, payload: payload).endpoint,
                responseType: SessionResponse.self
            )

            // Success — remove the retry payload from disk. The session is
            // torn down by WorkoutFeedbackView right after, which handles all
            // cache + notification cleanup via endSession().
            completionCacheService.remove(id: pendingCompletion.id)

            analyticsService.track("workout_completed", properties: [
                "duration_minutes": response.durationMinutes ?? 0,
                "calories": response.calories ?? 0,
                "exercise_count": exercises.count
            ] as [String: Any])

            saveToHealthKit(response: response)

            isLoading = false
            return response
        } catch {
            print("submitFeedbackAndComplete failed, cached for retry: \(error)")

            // Save to HealthKit even on failure so the user doesn't lose the record
            saveToHealthKit(response: nil)

            isLoading = false

            // Return a fallback response so the UI can dismiss normally
            return SessionResponse(
                id: sessionId,
                title: sessionTitle,
                type: "strength",
                status: "completed",
                startedAt: nil,
                completedAt: ISO8601DateFormatter().string(from: Date()),
                durationMinutes: trackedDuration,
                calories: nil,
                aiGenerated: nil,
                aiMessage: nil,
                exercises: []
            )
        }
    }

    private func saveToHealthKit(response: SessionResponse?) {
        // If the Watch tracked this session, HKLiveWorkoutBuilder.finishWorkout
        // already wrote an HKWorkout (with real HR + energy samples) to HealthKit
        // before the summary arrived here. Saving an iOS HKWorkout on top of that
        // creates a duplicate entry in Apple's Fitness app.
        guard sessionManager.watchWorkoutSummary == nil else { return }

        let elapsedSeconds = sessionManager.elapsedSeconds
        let title = sessionTitle
        let caloriesValue: Double? = response?.calories.map { Double($0) }
        let hkService = healthKitService
        Task.detached {
            do {
                let now = Date()
                let startDate = now.addingTimeInterval(-TimeInterval(elapsedSeconds))
                let workoutData = WorkoutData(
                    activityType: .traditionalStrengthTraining,
                    startDate: startDate,
                    endDate: now,
                    duration: TimeInterval(elapsedSeconds),
                    totalEnergyBurned: caloriesValue,
                    metadata: [
                        HKMetadataKeyWorkoutBrandName: "GymJam" as Any,
                        "SessionTitle": title as Any
                    ]
                )
                try await hkService.saveWorkout(workoutData)
            } catch {
                print("HealthKit save failed: \(error)")
            }
        }
    }
}
