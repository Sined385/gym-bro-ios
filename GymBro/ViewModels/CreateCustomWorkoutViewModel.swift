//
//  CreateCustomWorkoutViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-24.
//

import Foundation
import Combine

@MainActor
final class CreateCustomWorkoutViewModel: ObservableObject {

    @Published var workoutName: String = ""
    @Published var selectedExercises: [ExerciseLibraryItem] = []
    @Published var isSaving: Bool = false
    @Published var showExercisePicker: Bool = false

    var canSave: Bool {
        !workoutName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedExercises.isEmpty
    }

    var selectedExerciseIds: Set<String> {
        Set(selectedExercises.map(\.id))
    }

    private let networkService: NetworkServiceProtocol
    private let analyticsService: AnalyticsTrackingServiceProtocol

    init(networkService: NetworkServiceProtocol, analyticsService: AnalyticsTrackingServiceProtocol) {
        self.networkService = networkService
        self.analyticsService = analyticsService
    }

    func addExercise(_ exercise: ExerciseLibraryItem) {
        guard !selectedExerciseIds.contains(exercise.id) else { return }
        selectedExercises.append(exercise)
    }

    func removeExerciseById(_ id: String) {
        selectedExercises.removeAll { $0.id == id }
    }

    func saveWorkout() async -> WorkoutTemplate? {
        guard canSave else { return nil }
        isSaving = true
        defer { isSaving = false }

        let exercises: [[String: Any]] = selectedExercises.map { item in
            var dict: [String: Any] = [
                "name": item.name,
                "muscle_group": item.muscleGroup,
                "equipment": item.equipment
            ]
            if let externalId = item.externalId {
                dict["external_id"] = externalId
            }
            return dict
        }

        do {
            let template: WorkoutTemplate = try await networkService.request(
                TemplateRouter.createFromExercises(
                    name: workoutName.trimmingCharacters(in: .whitespaces),
                    exercises: exercises
                ).endpoint,
                responseType: WorkoutTemplate.self
            )
            analyticsService.track("custom_workout_created", properties: [
                "exercise_count": selectedExercises.count
            ])
            return template
        } catch {
            return nil
        }
    }
}
