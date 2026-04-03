//
//  WorkoutTemplateModels.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-02.
//

import Foundation

struct WorkoutTemplate: Decodable, Identifiable {
    let id: String
    let name: String
    let type: String
    let exercises: [TemplateExercise]
    let createdAt: String
}

struct TemplateExercise: Decodable, Identifiable {
    let name: String
    let muscleGroup: String
    let equipment: String?
    let setsDisplay: String
    let imageUrl: String?

    var id: String { name }
}

struct SharedTemplateCreator: Decodable {
    let id: String
    let name: String?
    let username: String?
    let avatarUrl: String?
    let primaryGoals: [String]?
    let experienceLevel: String?
    let bodyWeightKg: Double?
    let followerCount: Int?
    let followingCount: Int?
}

struct SharedTemplateResponse: Decodable {
    let name: String
    let shareCode: String?
    let creator: SharedTemplateCreator?
    let exercises: [TemplateExercise]
}
