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

    init(sessionId: String, sessionTitle: String, networkService: NetworkServiceProtocol, sessionManager: ActiveSessionManager, healthKitService: HealthKitServiceProtocol, initialExercises: [DashboardExercise] = [], restoredExercises: [ActiveSessionExercise]? = nil, restoredFeedback: (effort: Int, energy: Int, pain: String)? = nil) {
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.networkService = networkService
        self.sessionManager = sessionManager
        self.healthKitService = healthKitService

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
                    imageUrl: dashEx.imageUrl
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
        isLoading = true
        errorMessage = nil

        let exerciseData: [[String: Any]] = [[
            "library_exercise_id": item.id,
            "name": item.name,
            "muscle_group": item.muscleGroup,
            "equipment": item.equipment
        ]]

        do {
            let response = try await networkService.request(
                SessionRouter.addExercises(sessionId: sessionId, exercises: exerciseData).endpoint,
                responseType: AddExercisesResponse.self
            )

            for ex in response.exercises {
                let activeEx = ActiveSessionExercise(
                    id: ex.id,
                    libraryExerciseId: ex.libraryExerciseId,
                    name: ex.name,
                    muscleGroup: ex.muscleGroup ?? item.muscleGroup,
                    equipment: ex.equipment ?? item.equipment,
                    accentColor: ex.accentColor,
                    stepNumber: ex.stepNumber,
                    sets: [],
                    supersetGroupId: nil,
                    supersetOrder: nil,
                    targetSets: 0,
                    targetReps: 0,
                    imageUrl: ex.imageUrl
                )
                exercises.append(activeEx)
            }

            Analytics.logEvent("exercise_added", parameters: [
                "exercise_name": item.name,
                "muscle_group": item.muscleGroup
            ])
        } catch {
            // Mock fallback
            let mockExercise = ActiveSessionExercise(
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
                imageUrl: item.images?.first
            )
            exercises.append(mockExercise)
            errorMessage = nil  // Suppress while using mock
        }

        isLoading = false
        notifySessionChanged()
    }

    func addSuperset(_ exerciseIds: [String]) async {
        // exerciseIds are library exercise IDs selected in SupersetSelectionView
        // The API call will be: POST /api/v1/home/sessions/:id/supersets
        // For now we use items from ExerciseLibraryViewModel
        isLoading = true
        errorMessage = nil

        do {
            let response = try await networkService.request(
                SessionRouter.createSuperset(sessionId: sessionId, exerciseIds: exerciseIds).endpoint,
                responseType: SupersetResponse.self
            )

            let groupId = response.supersetGroupId
            for ex in response.exercises {
                let activeEx = ActiveSessionExercise(
                    id: ex.id,
                    libraryExerciseId: ex.libraryExerciseId,
                    name: ex.name,
                    muscleGroup: ex.muscleGroup ?? "",
                    equipment: ex.equipment ?? "",
                    accentColor: ex.accentColor,
                    stepNumber: ex.stepNumber,
                    sets: [],
                    supersetGroupId: groupId,
                    supersetOrder: ex.supersetOrder,
                    targetSets: 0,
                    targetReps: 0,
                    imageUrl: ex.imageUrl
                )
                exercises.append(activeEx)
            }
        } catch {
            // Mock: won't add superset on error for now
            errorMessage = nil
        }

        isLoading = false
        notifySessionChanged()
    }

    func addSupersetFromLibrary(_ items: [ExerciseLibraryItem]) async {
        isLoading = true
        errorMessage = nil

        // First add exercises, then group as superset
        let exerciseData = items.map { item in
            [
                "library_exercise_id": item.id,
                "name": item.name,
                "muscle_group": item.muscleGroup,
                "equipment": item.equipment
            ] as [String: Any]
        }

        do {
            let response = try await networkService.request(
                SessionRouter.addExercises(sessionId: sessionId, exercises: exerciseData).endpoint,
                responseType: AddExercisesResponse.self
            )

            // Now create superset from the returned exercise IDs
            let newExerciseIds = response.exercises.map { $0.id }
            let supersetResp = try await networkService.request(
                SessionRouter.createSuperset(sessionId: sessionId, exerciseIds: newExerciseIds).endpoint,
                responseType: SupersetResponse.self
            )

            let groupId = supersetResp.supersetGroupId
            for ex in supersetResp.exercises {
                let activeEx = ActiveSessionExercise(
                    id: ex.id,
                    libraryExerciseId: ex.libraryExerciseId,
                    name: ex.name,
                    muscleGroup: ex.muscleGroup ?? "",
                    equipment: ex.equipment ?? "",
                    accentColor: ex.accentColor,
                    stepNumber: ex.stepNumber,
                    sets: [],
                    supersetGroupId: groupId,
                    supersetOrder: ex.supersetOrder,
                    targetSets: 0,
                    targetReps: 0,
                    imageUrl: ex.imageUrl
                )
                exercises.append(activeEx)
            }
        } catch {
            // Mock fallback
            let groupId = UUID().uuidString
            let orders = ["A", "B", "C", "D", "E"]
            for (index, item) in items.enumerated() {
                let mockExercise = ActiveSessionExercise(
                    id: UUID().uuidString,
                    libraryExerciseId: item.id,
                    name: item.name,
                    muscleGroup: item.muscleGroup,
                    equipment: item.equipment,
                    accentColor: nextAccentColor(),
                    stepNumber: exercises.count + 1,
                    sets: [],
                    supersetGroupId: groupId,
                    supersetOrder: index < orders.count ? orders[index] : "\(index)",
                    targetSets: 0,
                    targetReps: 0,
                    imageUrl: item.images?.first
                )
                exercises.append(mockExercise)
            }
            errorMessage = nil
        }

        isLoading = false
        notifySessionChanged()
    }

    func removeExercise(_ exerciseId: String) async {
        // Optimistic UI update
        exercises.removeAll { $0.id == exerciseId }
        notifySessionChanged()

        // Background API call
        let sid = sessionId
        let ns = networkService
        Task.detached { [sid, ns] in
            try? await ns.request(
                SessionRouter.removeExercise(sessionId: sid, exerciseId: exerciseId).endpoint
            )
        }
    }

    // MARK: - Set Management

    /// Completes a pre-created placeholder set with entered weight/reps.
    /// UI updates instantly; API call fires in the background.
    func completeSet(exerciseId: String, setId: String, weight: Double?, reps: Int) async {
        sessionManager.cancelStillThereNotification()

        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) else { return }

        let setNumber = exercises[exerciseIndex].sets[setIndex].setNumber

        // Optimistic UI update
        exercises[exerciseIndex].sets[setIndex].weight = weight
        exercises[exerciseIndex].sets[setIndex].reps = reps
        exercises[exerciseIndex].sets[setIndex].isCompleted = true
        notifySessionChanged()

        Analytics.logEvent("set_logged", parameters: [
            "exercise_name": exercises[exerciseIndex].name,
            "weight": weight ?? 0,
            "reps": reps
        ] as [String: Any])

        // Background API call
        let sid = sessionId
        let ns = networkService
        Task.detached { [sid, ns] in
            do {
                let response = try await ns.request(
                    SessionRouter.logSet(
                        sessionId: sid, exerciseId: exerciseId,
                        setNumber: setNumber, weight: weight as Any, weightUnit: "kg", reps: reps
                    ).endpoint,
                    responseType: SetResponse.self
                )
                await MainActor.run { [weak self] in
                    guard let self,
                          let ei = self.exercises.firstIndex(where: { $0.id == exerciseId }),
                          let si = self.exercises[ei].sets.firstIndex(where: { $0.id == setId }) else { return }
                    self.exercises[ei].sets[si].id = response.id
                }
            } catch {
                // Local update already applied
            }
        }
    }

    /// Logs a new set. UI updates instantly; API call fires in the background.
    func logSet(exerciseId: String, weight: Double?, weightUnit: String = "kg", reps: Int) async {
        sessionManager.cancelStillThereNotification()

        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        let setNumber = exercises[exerciseIndex].sets.count + 1
        let localId = UUID().uuidString

        // Optimistic UI update
        let optimisticSet = ActiveSet(
            id: localId,
            setNumber: setNumber,
            weight: weight,
            weightUnit: weightUnit,
            reps: reps,
            isCompleted: true
        )
        exercises[exerciseIndex].sets.append(optimisticSet)
        notifySessionChanged()

        // Background API call
        let sid = sessionId
        let ns = networkService
        Task.detached { [sid, ns] in
            do {
                let response = try await ns.request(
                    SessionRouter.logSet(
                        sessionId: sid, exerciseId: exerciseId,
                        setNumber: setNumber, weight: weight as Any, weightUnit: weightUnit, reps: reps
                    ).endpoint,
                    responseType: SetResponse.self
                )
                await MainActor.run { [weak self] in
                    guard let self,
                          let ei = self.exercises.firstIndex(where: { $0.id == exerciseId }),
                          let si = self.exercises[ei].sets.firstIndex(where: { $0.id == localId }) else { return }
                    self.exercises[ei].sets[si].id = response.id
                }
            } catch {
                // Local update already applied
            }
        }
    }

    /// Updates a set. UI updates instantly; API call fires in the background.
    func updateSet(exerciseId: String, setId: String, weight: Double?, weightUnit: String?, reps: Int?, isCompleted: Bool?) async {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) else { return }

        // Optimistic UI update
        if let weight = weight { exercises[exerciseIndex].sets[setIndex].weight = weight }
        if let weightUnit = weightUnit { exercises[exerciseIndex].sets[setIndex].weightUnit = weightUnit }
        if let reps = reps { exercises[exerciseIndex].sets[setIndex].reps = reps }
        if let isCompleted = isCompleted { exercises[exerciseIndex].sets[setIndex].isCompleted = isCompleted }
        notifySessionChanged()

        // Background API call
        var params: [String: Any] = [:]
        if let weight = weight { params["weight"] = weight }
        if let weightUnit = weightUnit { params["weight_unit"] = weightUnit }
        if let reps = reps { params["reps"] = reps }
        if let isCompleted = isCompleted { params["is_completed"] = isCompleted }

        let sid = sessionId
        let ns = networkService
        Task.detached { [sid, ns] in
            try? await ns.request(
                SessionRouter.updateSet(sessionId: sid, exerciseId: exerciseId, setId: setId, params: params).endpoint
            )
        }
    }

    /// Deletes a set. UI updates instantly; API call fires in the background.
    func deleteSet(exerciseId: String, setId: String) async {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        // Optimistic UI update
        exercises[exerciseIndex].sets.removeAll { $0.id == setId }
        notifySessionChanged()

        // Background API call
        let sid = sessionId
        let ns = networkService
        Task.detached { [sid, ns] in
            try? await ns.request(
                SessionRouter.deleteSet(sessionId: sid, exerciseId: exerciseId, setId: setId).endpoint
            )
        }
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

    // MARK: - Exercise Images

    func fetchExerciseImages(libraryExerciseId: String) async -> [String] {
        do {
            let response = try await networkService.request(
                ExerciseRouter.detail(exerciseId: libraryExerciseId).endpoint,
                responseType: ExerciseDetailResponse.self
            )
            return response.images ?? []
        } catch {
            return []
        }
    }

    // MARK: - Session Completion

    func submitFeedbackAndComplete() async -> SessionResponse? {
        sessionManager.stopTimer()
        isLoading = true
        errorMessage = nil

        let feedback: [String: Any] = [
            "effort_level": effortLevel,
            "energy_level": energyLevel,
            "pain_discomfort": painDiscomfort
        ]

        do {
            let response = try await networkService.request(
                SessionRouter.completeWithFeedback(sessionId: sessionId, feedback: feedback).endpoint,
                responseType: SessionResponse.self
            )

            Analytics.logEvent("workout_completed", parameters: [
                "duration_minutes": response.durationMinutes ?? 0,
                "calories": response.calories ?? 0,
                "effort_level": effortLevel,
                "exercise_count": exercises.count
            ] as [String: Any])

            // Fire-and-forget HealthKit save
            let elapsedSeconds = sessionManager.elapsedSeconds
            let title = sessionTitle
            let caloriesValue = response.calories
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
                        totalEnergyBurned: caloriesValue.map { Double($0) },
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

            isLoading = false
            return response
        } catch {
            // Still dismiss the flow on failure
            print("❌ submitFeedbackAndComplete failed: \(error)")
            isLoading = false
            return nil
        }
    }
}
