//
//  WorkoutSessionModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import SwiftData

/// SwiftData model for workout sessions
@Model
final class WorkoutSessionModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var duration: TimeInterval
    var totalCaloriesBurned: Double?
    var totalDistanceMeters: Double?
    var workoutType: String // Stored as string for flexibility
    var notes: String?
    var isSyncedToHealthKit: Bool
    var healthKitWorkoutId: UUID?

    @Relationship(deleteRule: .cascade) var exercises: [ExerciseModel]?

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval? = nil,
        totalCaloriesBurned: Double? = nil,
        totalDistanceMeters: Double? = nil,
        workoutType: String,
        notes: String? = nil,
        isSyncedToHealthKit: Bool = false,
        healthKitWorkoutId: UUID? = nil,
        exercises: [ExerciseModel]? = nil
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration ?? endDate.timeIntervalSince(startDate)
        self.totalCaloriesBurned = totalCaloriesBurned
        self.totalDistanceMeters = totalDistanceMeters
        self.workoutType = workoutType
        self.notes = notes
        self.isSyncedToHealthKit = isSyncedToHealthKit
        self.healthKitWorkoutId = healthKitWorkoutId
        self.exercises = exercises
    }
}

/// SwiftData model for individual exercises within a workout
@Model
final class ExerciseModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var exerciseType: String // "strength", "cardio", "flexibility", etc.
    var sets: Int?
    var reps: Int?
    var weight: Double? // in kilograms
    var duration: TimeInterval?
    var distance: Double? // in meters
    var caloriesBurned: Double?
    var notes: String?
    var orderIndex: Int

    @Relationship(inverse: \WorkoutSessionModel.exercises) var workout: WorkoutSessionModel?

    init(
        id: UUID = UUID(),
        name: String,
        exerciseType: String,
        sets: Int? = nil,
        reps: Int? = nil,
        weight: Double? = nil,
        duration: TimeInterval? = nil,
        distance: Double? = nil,
        caloriesBurned: Double? = nil,
        notes: String? = nil,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.exerciseType = exerciseType
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.caloriesBurned = caloriesBurned
        self.notes = notes
        self.orderIndex = orderIndex
    }
}
