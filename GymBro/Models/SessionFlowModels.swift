//
//  SessionFlowModels.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import Foundation

// MARK: - Exercise Library

struct ExerciseLibraryItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let muscleGroup: String
    let equipment: String
    let isSystem: Bool
    var images: [String]? = nil
}

struct ExerciseLibraryResponse: Decodable {
    let exercises: [ExerciseLibraryItem]  // or just decode as array
}

// MARK: - Muscle Group

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case other = "Other"

    var id: String { rawValue }
}

// MARK: - Previous Sets

struct PreviousSetsResponse: Decodable {
    let exerciseId: String
    let sessions: [PreviousSessionEntry]
}

struct PreviousSessionEntry: Decodable, Identifiable {
    let sessionDate: String?
    let sets: [PreviousSet]
    var id: String { sessionDate ?? UUID().uuidString }
}

struct PreviousSet: Decodable, Identifiable {
    let setNumber: Int
    let weight: Double?
    let weightUnit: String
    let reps: Int
    var id: Int { setNumber }
}

// MARK: - Active Session Exercise

struct ActiveSessionExercise: Identifiable, Equatable, Codable {
    let id: String
    let libraryExerciseId: String?
    var name: String
    var muscleGroup: String
    var equipment: String
    var accentColor: String
    var stepNumber: Int
    var sets: [ActiveSet]
    var supersetGroupId: String?
    var supersetOrder: String?  // "A", "B", "C"
    var targetSets: Int
    var targetReps: Int

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Active Set

struct ActiveSet: Identifiable, Equatable, Codable {
    var id: String
    var setNumber: Int
    var weight: Double?
    var weightUnit: String
    var reps: Int?
    var isCompleted: Bool
}

// MARK: - Superset Group

struct SupersetGroup: Identifiable {
    let id: String  // superset_group_id
    var exercises: [ActiveSessionExercise]

    var displayName: String {
        exercises.map { $0.name }.joined(separator: " + ")
    }
}

// MARK: - API Request Types

struct AddExercisesRequest: Encodable {
    let exercises: [AddExerciseItem]
}

struct AddExerciseItem: Encodable {
    let libraryExerciseId: String?
    let name: String
    let muscleGroup: String
    let equipment: String
}

struct CreateSupersetRequest: Encodable {
    let exerciseIds: [String]
}

struct LogSetRequest: Encodable {
    let setNumber: Int
    let weight: Double?
    let weightUnit: String
    let reps: Int
}

struct UpdateSetRequest: Encodable {
    let weight: Double?
    let weightUnit: String?
    let reps: Int?
    let isCompleted: Bool?
}

struct FeedbackRequest: Encodable {
    let effortLevel: Int
    let energyLevel: Int
    let painDiscomfort: String
}

struct CreateCustomExerciseRequest: Encodable {
    let name: String
    let muscleGroup: String
    let equipment: String
}

// MARK: - API Response Types for session exercises

struct AddExercisesResponse: Decodable {
    let exercises: [SessionExerciseResponse]
}

struct SessionExerciseResponse: Decodable, Identifiable {
    let id: String
    let name: String
    let muscleGroup: String?
    let equipment: String?
    let accentColor: String
    let stepNumber: Int
    let libraryExerciseId: String?
    let supersetGroupId: String?
    let supersetOrder: String?
    let sets: [SetResponse]?
}

// MARK: - Exercise Detail (on-demand image fetch)

struct ExerciseDetailResponse: Decodable {
    let id: String
    let images: [String]?
}

struct SetResponse: Decodable, Identifiable {
    let id: String
    let setNumber: Int
    let weight: Double?
    let weightUnit: String
    let reps: Int
    let isCompleted: Bool
}

struct SupersetResponse: Decodable {
    let supersetGroupId: String
    let exercises: [SessionExerciseResponse]
}
