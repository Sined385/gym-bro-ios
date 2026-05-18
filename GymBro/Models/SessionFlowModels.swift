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
    var isFavorite: Bool = false
    var images: [String]? = nil
    var externalId: String? = nil
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

// MARK: - Equipment Type

enum EquipmentType: String, CaseIterable, Identifiable {
    case barbell = "Barbell"
    case dumbbells = "Dumbbells"
    case cable = "Cable"
    case machine = "Machine"
    case bodyweight = "Bodyweight"

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
    let isBodyweight: Bool

    private enum CodingKeys: String, CodingKey {
        case setNumber, weight, weightUnit, reps, isBodyweight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.setNumber = try c.decode(Int.self, forKey: .setNumber)
        self.weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        self.weightUnit = try c.decodeIfPresent(String.self, forKey: .weightUnit) ?? "kg"
        self.reps = try c.decode(Int.self, forKey: .reps)
        self.isBodyweight = try c.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
    }

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
    var imageUrl: String?
    var externalId: String?
    // Defaults to false; the FavoritesService is the live source of truth and
    // the heart icon reads from there. This field exists so the model round-trips
    // through SwiftData persistence cleanly if we ever switch to it.
    var isFavorite: Bool = false

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
    // Defaults to false so existing CachedSession blobs in UserDefaults decode
    // without a migration. New sets honor the user's bodyweight toggle.
    var isBodyweight: Bool = false
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
    let imageUrl: String?
    let externalId: String?
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
    let isBodyweight: Bool

    private enum CodingKeys: String, CodingKey {
        case id, setNumber, weight, weightUnit, reps, isCompleted, isBodyweight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.setNumber = try c.decode(Int.self, forKey: .setNumber)
        self.weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        self.weightUnit = try c.decodeIfPresent(String.self, forKey: .weightUnit) ?? "kg"
        self.reps = try c.decode(Int.self, forKey: .reps)
        self.isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        self.isBodyweight = try c.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
    }
}

struct SupersetResponse: Decodable {
    let supersetGroupId: String
    let exercises: [SessionExerciseResponse]
}
