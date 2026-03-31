//
//  ExercisePreviewData.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-31.
//

import Foundation

struct ExercisePreviewData: Identifiable {
    let id: String
    let libraryExerciseId: String?
    let name: String
    let muscleGroup: String?
    let equipment: String?
    let setsDisplay: String
    let accentColor: String
    let suggestedWeight: Double?

    init(from ex: DashboardExercise) {
        self.id = ex.libraryExerciseId ?? UUID().uuidString
        self.libraryExerciseId = ex.libraryExerciseId
        self.name = ex.name
        self.muscleGroup = ex.muscleGroup
        self.equipment = ex.equipment
        self.setsDisplay = ex.setsDisplay
        self.accentColor = ex.accentColor
        self.suggestedWeight = ex.suggestedWeight
    }

    init(from ex: PlanExercise) {
        self.id = ex.libraryExerciseId ?? UUID().uuidString
        self.libraryExerciseId = ex.libraryExerciseId
        self.name = ex.name
        self.muscleGroup = ex.muscleGroup
        self.equipment = nil
        self.setsDisplay = ex.setsDisplay
        self.accentColor = ex.accentColor ?? "E86A75"
        self.suggestedWeight = ex.suggestedWeight
    }
}
