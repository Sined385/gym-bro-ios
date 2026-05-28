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
    var lastSet: ExerciseLibraryLastSet? = nil

    init(
        id: String,
        name: String,
        muscleGroup: String,
        equipment: String,
        isSystem: Bool,
        isFavorite: Bool = false,
        images: [String]? = nil,
        externalId: String? = nil,
        lastSet: ExerciseLibraryLastSet? = nil
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.isSystem = isSystem
        self.isFavorite = isFavorite
        self.images = images
        self.externalId = externalId
        self.lastSet = lastSet
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, muscleGroup, equipment, isSystem, isFavorite, images, externalId, lastSet
    }

    // Why: synthesized Decodable doesn't honor default values for missing keys,
    // so a backend that hasn't shipped `is_favorite` yet would throw on decode and
    // drop the entire library to the mock fallback (which has no externalId, so
    // exercise demo images go blank). decodeIfPresent keeps the client tolerant.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.muscleGroup = try c.decode(String.self, forKey: .muscleGroup)
        self.equipment = try c.decode(String.self, forKey: .equipment)
        self.isSystem = try c.decodeIfPresent(Bool.self, forKey: .isSystem) ?? true
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.images = try c.decodeIfPresent([String].self, forKey: .images)
        self.externalId = try c.decodeIfPresent(String.self, forKey: .externalId)
        self.lastSet = try c.decodeIfPresent(ExerciseLibraryLastSet.self, forKey: .lastSet)
    }
}

/// Last set the user logged for this library exercise, surfaced on the
/// library card so the user can recall where they left off.
struct ExerciseLibraryLastSet: Decodable, Hashable {
    let weight: Double?
    let weightUnit: String
    let reps: Int
    let isBodyweight: Bool
    let completedAt: String?
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
    var isFavorite: Bool = false

    init(
        id: String,
        libraryExerciseId: String?,
        name: String,
        muscleGroup: String,
        equipment: String,
        accentColor: String,
        stepNumber: Int,
        sets: [ActiveSet],
        supersetGroupId: String?,
        supersetOrder: String?,
        targetSets: Int,
        targetReps: Int,
        imageUrl: String?,
        externalId: String?,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.libraryExerciseId = libraryExerciseId
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.accentColor = accentColor
        self.stepNumber = stepNumber
        self.sets = sets
        self.supersetGroupId = supersetGroupId
        self.supersetOrder = supersetOrder
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.imageUrl = imageUrl
        self.externalId = externalId
        self.isFavorite = isFavorite
    }

    private enum CodingKeys: String, CodingKey {
        case id, libraryExerciseId, name, muscleGroup, equipment, accentColor, stepNumber, sets, supersetGroupId, supersetOrder, targetSets, targetReps, imageUrl, externalId, isFavorite
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.libraryExerciseId = try c.decodeIfPresent(String.self, forKey: .libraryExerciseId)
        self.name = try c.decode(String.self, forKey: .name)
        self.muscleGroup = try c.decode(String.self, forKey: .muscleGroup)
        self.equipment = try c.decode(String.self, forKey: .equipment)
        self.accentColor = try c.decode(String.self, forKey: .accentColor)
        self.stepNumber = try c.decode(Int.self, forKey: .stepNumber)
        self.sets = try c.decodeIfPresent([ActiveSet].self, forKey: .sets) ?? []
        self.supersetGroupId = try c.decodeIfPresent(String.self, forKey: .supersetGroupId)
        self.supersetOrder = try c.decodeIfPresent(String.self, forKey: .supersetOrder)
        self.targetSets = try c.decodeIfPresent(Int.self, forKey: .targetSets) ?? 0
        self.targetReps = try c.decodeIfPresent(Int.self, forKey: .targetReps) ?? 0
        self.imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        self.externalId = try c.decodeIfPresent(String.self, forKey: .externalId)
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

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
    var isBodyweight: Bool = false

    init(
        id: String,
        setNumber: Int,
        weight: Double? = nil,
        weightUnit: String,
        reps: Int? = nil,
        isCompleted: Bool,
        isBodyweight: Bool = false
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weight = weight
        self.weightUnit = weightUnit
        self.reps = reps
        self.isCompleted = isCompleted
        self.isBodyweight = isBodyweight
    }

    private enum CodingKeys: String, CodingKey {
        case id, setNumber, weight, weightUnit, reps, isCompleted, isBodyweight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.setNumber = try c.decode(Int.self, forKey: .setNumber)
        self.weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        self.weightUnit = try c.decodeIfPresent(String.self, forKey: .weightUnit) ?? "kg"
        self.reps = try c.decodeIfPresent(Int.self, forKey: .reps)
        self.isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        self.isBodyweight = try c.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
    }
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
