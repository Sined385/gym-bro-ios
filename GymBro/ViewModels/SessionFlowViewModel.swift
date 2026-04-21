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
    @Published var pendingExerciseId: String?

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
    private var repeatLastSetCancellable: AnyCancellable?

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

    // MARK: - Accent Colors

    private static let accentColors = ["#E86A75", "#30C08D", "#7A82F6", "#F5A623"]

    private func nextAccentColor() -> String {
        let index = exercises.count % Self.accentColors.count
        return Self.accentColors[index]
    }

    // MARK: - Initialization

    init(sessionId: String, sessionTitle: String, networkService: NetworkServiceProtocol, sessionManager: ActiveSessionManager, healthKitService: HealthKitServiceProtocol, analyticsService: AnalyticsTrackingServiceProtocol, subscriptionManager: SubscriptionManager = DependencyContainer.shared.resolve(SubscriptionManager.self), initialExercises: [DashboardExercise] = [], restoredExercises: [ActiveSessionExercise]? = nil, restoredFeedback: (effort: Int, energy: Int, pain: String)? = nil) {
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.networkService = networkService
        self.sessionManager = sessionManager
        self.healthKitService = healthKitService
        self.analyticsService = analyticsService
        self.subscriptionManager = subscriptionManager

        if let restored = restoredExercises {
            _exercises = Published(wrappedValue: restored)
            if let feedback = restoredFeedback {
                _effortLevel = Published(wrappedValue: feedback.effort)
                _energyLevel = Published(wrappedValue: feedback.energy)
                _painDiscomfort = Published(wrappedValue: feedback.pain)
            }
            // Clear restored data from session manager
            sessionManager.restoredExercises = nil
            sessionManager.restoredFeedback = nil
            // Sync exercises back to session manager for persistence
            Task { [weak self] in
                self?.notifySessionChanged()
            }
        } else {
            // Convert DashboardExercises to ActiveSessionExercises with pre-created placeholder sets
            let converted = initialExercises.map { dashEx in
                let (targetSets, targetReps) = Self.parseSetsDisplay(dashEx.setsDisplay)
                // Pre-create placeholder sets based on target
                let placeholderSets = (1...max(targetSets, 1)).map { setNum in
                    ActiveSet(
                        id: UUID().uuidString,
                        setNumber: setNum,
                        weight: dashEx.suggestedWeight,
                        weightUnit: "kg",
                        reps: targetReps > 0 ? targetReps : nil,
                        isCompleted: false
                    )
                }
                return ActiveSessionExercise(
                    id: dashEx.id,
                    libraryExerciseId: dashEx.libraryExerciseId,
                    name: dashEx.name,
                    muscleGroup: dashEx.muscleGroup ?? "",
                    equipment: dashEx.equipment ?? "",
                    accentColor: dashEx.accentColor,
                    stepNumber: dashEx.stepNumber,
                    sets: placeholderSets,
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
            if !initialExercises.isEmpty {
                Task { [weak self] in
                    self?.notifySessionChanged()
                }
            }
        }

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
            externalId: item.externalId
        )
        exercises.append(newExercise)

        analyticsService.track("exercise_added", properties: [
            "exercise_name": item.name,
            "muscle_group": item.muscleGroup
        ])

        notifySessionChanged()
    }

    func addExercisePending(_ item: ExerciseLibraryItem) async -> String {
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
            externalId: item.externalId
        )
        exercises.append(newExercise)
        pendingExerciseId = newExercise.id
        return newExercise.id
    }

    func confirmPendingExercise() {
        guard let pendingId = pendingExerciseId else { return }
        pendingExerciseId = nil
        notifySessionChanged()
        analyticsService.track("pending_exercise_confirmed", properties: [
            "exercise_id": pendingId
        ])
    }

    func discardPendingExercise() {
        guard let pendingId = pendingExerciseId else { return }
        exercises.removeAll { $0.id == pendingId }
        pendingExerciseId = nil
    }

    func addSuperset(_ exerciseIds: [String]) async {
        guard subscriptionManager.requireFeature(.supersets) else { return }
        // Local-only: group existing exercises into a superset
        let groupId = UUID().uuidString
        let orders = ["A", "B", "C", "D", "E"]
        for (index, exerciseId) in exerciseIds.enumerated() {
            if let idx = exercises.firstIndex(where: { $0.id == exerciseId }) {
                exercises[idx].supersetGroupId = groupId
                exercises[idx].supersetOrder = index < orders.count ? orders[index] : "\(index)"
            }
        }
        analyticsService.track("superset_created", properties: ["exercise_count": exerciseIds.count])
        notifySessionChanged()
    }

    func addSupersetFromLibrary(_ items: [ExerciseLibraryItem]) async {
        guard subscriptionManager.requireFeature(.supersets) else { return }
        let groupId = UUID().uuidString
        let orders = ["A", "B", "C", "D", "E"]
        for (index, item) in items.enumerated() {
            let order = index < orders.count ? orders[index] : "\(index)"
            // If exercise is already in the session, group it instead of duplicating
            if let existingIndex = exercises.firstIndex(where: { $0.libraryExerciseId == item.id && $0.supersetGroupId == nil }) {
                exercises[existingIndex].supersetGroupId = groupId
                exercises[existingIndex].supersetOrder = order
            } else {
                let newExercise = ActiveSessionExercise(
                    id: UUID().uuidString,
                    libraryExerciseId: item.id,
                    name: item.name,
                    muscleGroup: item.muscleGroup,
                    equipment: item.equipment,
                    accentColor: nextAccentColor(),
                    stepNumber: exercises.count + 1,
                    sets: [],
                    supersetGroupId: groupId,
                    supersetOrder: order,
                    targetSets: 0,
                    targetReps: 0,
                    imageUrl: ExerciseImageURLBuilder.thumbnailURL(for: item.externalId)?.absoluteString ?? item.images?.first,
                    externalId: item.externalId
                )
                exercises.append(newExercise)
            }
        }
        analyticsService.track("superset_created", properties: ["exercise_count": items.count])
        notifySessionChanged()
    }

    func removeExercise(_ exerciseId: String) async {
        exercises.removeAll { $0.id == exerciseId }
        notifySessionChanged()
    }

    func removeSuperset(_ groupId: String) async {
        exercises.removeAll { $0.supersetGroupId == groupId }
        notifySessionChanged()
    }

    // MARK: - Set Management

    func completeSet(exerciseId: String, setId: String, weight: Double?, reps: Int) async {
        sessionManager.cancelStillThereNotification()

        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) else { return }

        exercises[exerciseIndex].sets[setIndex].weight = weight
        exercises[exerciseIndex].sets[setIndex].reps = reps
        exercises[exerciseIndex].sets[setIndex].isCompleted = true

        if exerciseId == pendingExerciseId {
            confirmPendingExercise()
        } else {
            notifySessionChanged()
        }

        sessionManager.updateLastCompletedSet(
            exerciseName: exercises[exerciseIndex].name,
            weight: weight,
            weightUnit: exercises[exerciseIndex].sets[setIndex].weightUnit,
            reps: reps
        )

        Analytics.logEvent("set_logged", parameters: [
            "exercise_name": exercises[exerciseIndex].name,
            "weight": weight ?? 0,
            "reps": reps
        ] as [String: Any])
    }

    func logSet(exerciseId: String, weight: Double?, weightUnit: String = "kg", reps: Int) async {
        sessionManager.cancelStillThereNotification()

        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        let setNumber = exercises[exerciseIndex].sets.count + 1
        let newSet = ActiveSet(
            id: UUID().uuidString,
            setNumber: setNumber,
            weight: weight,
            weightUnit: weightUnit,
            reps: reps,
            isCompleted: true
        )
        exercises[exerciseIndex].sets.append(newSet)

        if exerciseId == pendingExerciseId {
            confirmPendingExercise()
        } else {
            notifySessionChanged()
        }

        sessionManager.updateLastCompletedSet(
            exerciseName: exercises[exerciseIndex].name,
            weight: weight,
            weightUnit: weightUnit,
            reps: reps
        )
    }

    func updateSet(exerciseId: String, setId: String, weight: Double?, weightUnit: String?, reps: Int?, isCompleted: Bool?) async {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) else { return }

        if let weight = weight { exercises[exerciseIndex].sets[setIndex].weight = weight }
        if let weightUnit = weightUnit { exercises[exerciseIndex].sets[setIndex].weightUnit = weightUnit }
        if let reps = reps { exercises[exerciseIndex].sets[setIndex].reps = reps }
        if let isCompleted = isCompleted { exercises[exerciseIndex].sets[setIndex].isCompleted = isCompleted }
        notifySessionChanged()
    }

    func deleteSet(exerciseId: String, setId: String) async {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        exercises[exerciseIndex].sets.removeAll { $0.id == setId }
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
        await completeSet(exerciseId: exerciseId, setId: setId, weight: weight, reps: reps)
    }

    // MARK: - Session Completion

    func submitFeedbackAndComplete() async -> SessionResponse? {
        sessionManager.stopTimer()
        sessionManager.pushWatchSessionEnded()
        isLoading = true
        errorMessage = nil

        let trackedDuration = max(1, sessionManager.elapsedSeconds / 60)

        let payload: [String: Any] = [
            "duration_minutes": trackedDuration,
            "feedback": [
                "effort_level": effortLevel,
                "energy_level": energyLevel,
                "pain_discomfort": painDiscomfort
            ],
            "exercises": exercises.map { ex -> [String: Any] in
                var dict: [String: Any] = [
                    "name": ex.name,
                    "muscle_group": ex.muscleGroup,
                    "step_number": ex.stepNumber,
                    "sets": ex.sets.filter(\.isCompleted).map { set -> [String: Any] in
                        var setDict: [String: Any] = [
                            "set_number": set.setNumber,
                            "reps": set.reps ?? 0,
                            "is_completed": set.isCompleted
                        ]
                        if let weight = set.weight { setDict["weight"] = weight }
                        setDict["weight_unit"] = set.weightUnit
                        return setDict
                    }
                ]
                if let libId = ex.libraryExerciseId { dict["library_exercise_id"] = libId }
                dict["equipment"] = ex.equipment
                dict["accent_color"] = ex.accentColor
                if let groupId = ex.supersetGroupId { dict["superset_group_id"] = groupId }
                if let order = ex.supersetOrder { dict["superset_order"] = order }
                return dict
            }
        ]

        do {
            let response = try await networkService.request(
                SessionRouter.completeSessionFull(sessionId: sessionId, payload: payload).endpoint,
                responseType: SessionResponse.self
            )

            analyticsService.track("workout_completed", properties: [
                "duration_minutes": response.durationMinutes ?? 0,
                "calories": response.calories ?? 0,
                "exercise_count": exercises.count
            ] as [String: Any])

            // Fire-and-forget HealthKit save — skip if Watch managed the HKWorkoutSession
            // (Watch already saved the workout with real HR/calorie data)
            if !sessionManager.isWatchManagingWorkout {
                let elapsedSeconds = sessionManager.elapsedSeconds
                let title = sessionTitle
                // Prefer Watch-sourced calories over API MET-estimated calories
                let watchSummary = sessionManager.watchWorkoutSummary
                let caloriesValue: Double? = watchSummary?.activeCalories ?? response.calories.map { Double($0) }
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

            isLoading = false
            return response
        } catch {
            print("❌ submitFeedbackAndComplete failed: \(error)")
            isLoading = false
            return nil
        }
    }
}
