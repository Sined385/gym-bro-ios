//
//  TrainingPlanModels.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import Foundation

struct TrainingPlanResponse: Decodable {
    let plan: TrainingPlanData?
    let days: [PlanDayData]
    let todayIndex: Int
}

struct TrainingPlanData: Decodable, Identifiable {
    let id: String
    let weekNumber: Int
    let primaryGoals: [String]
    let experienceLevel: String
}

struct PlanDayData: Decodable, Identifiable {
    let id: String
    let dayOfWeek: Int
    let dayLabel: String
    let dayType: String
    let status: String
    let sessionTitle: String?
    let sessionType: String?
    let muscleGroups: [String]?
    let exercises: [PlanExercise]?
    let workoutSession: PlanWorkoutSession?
    let aiNotes: String?
}

struct PlanExercise: Decodable, Identifiable {
    let name: String
    let muscleGroup: String
    let setsDisplay: String
    let libraryExerciseId: String?
    let accentColor: String?
    let suggestedWeight: Double?
    let imageUrl: String?
    let externalId: String?
    /// Per-set targets persisted on the plan day's exercises_json.
    /// Lets the Plan tab's preview sheet render the full ladder
    /// instead of the generic sets_display pill.
    let sets: [DashboardExerciseSet]?
    var id: String { name + setsDisplay }

    init(name: String, muscleGroup: String, setsDisplay: String, libraryExerciseId: String? = nil, accentColor: String? = nil, suggestedWeight: Double? = nil, imageUrl: String? = nil, externalId: String? = nil, sets: [DashboardExerciseSet]? = nil) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.setsDisplay = setsDisplay
        self.libraryExerciseId = libraryExerciseId
        self.accentColor = accentColor
        self.suggestedWeight = suggestedWeight
        self.imageUrl = imageUrl
        self.externalId = externalId
        self.sets = sets
    }
}

struct PlanWorkoutSession: Decodable {
    let id: String
    let durationMinutes: Int?
    let completedAt: String?
}
