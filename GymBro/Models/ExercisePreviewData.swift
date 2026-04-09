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
    let externalId: String?

    init(from ex: DashboardExercise) {
        self.id = ex.libraryExerciseId ?? UUID().uuidString
        self.libraryExerciseId = ex.libraryExerciseId
        self.name = ex.name
        self.muscleGroup = ex.muscleGroup
        self.equipment = ex.equipment
        self.setsDisplay = ex.setsDisplay
        self.accentColor = ex.accentColor
        self.suggestedWeight = ex.suggestedWeight
        self.externalId = ex.externalId
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
        self.externalId = ex.externalId
    }

    init(name: String, muscleGroup: String, setsDisplay: String, accentColor: String, suggestedWeight: Double?, externalId: String? = nil) {
        self.id = UUID().uuidString
        self.libraryExerciseId = nil
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = nil
        self.setsDisplay = setsDisplay
        self.accentColor = accentColor
        self.suggestedWeight = suggestedWeight
        self.externalId = externalId
    }
}
