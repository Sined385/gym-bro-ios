//
//  UserProfileModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import SwiftData

/// SwiftData model for user profile
@Model
final class UserProfileModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String?
    var dateOfBirth: Date?
    var gender: String?
    var heightCm: Double?
    var createdAt: Date
    var updatedAt: Date

    // Fitness goals
    var targetWeight: Double? // in kilograms
    var weeklyWorkoutGoal: Int? // number of workouts per week
    var dailyCalorieGoal: Double? // calories to burn per day

    // Preferences
    var preferredWorkoutTypes: [String]?
    var reminderTime: Date?
    var enableNotifications: Bool

    init(
        id: UUID = UUID(),
        name: String,
        email: String? = nil,
        dateOfBirth: Date? = nil,
        gender: String? = nil,
        heightCm: Double? = nil,
        targetWeight: Double? = nil,
        weeklyWorkoutGoal: Int? = nil,
        dailyCalorieGoal: Double? = nil,
        preferredWorkoutTypes: [String]? = nil,
        reminderTime: Date? = nil,
        enableNotifications: Bool = true
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.heightCm = heightCm
        self.createdAt = Date()
        self.updatedAt = Date()
        self.targetWeight = targetWeight
        self.weeklyWorkoutGoal = weeklyWorkoutGoal
        self.dailyCalorieGoal = dailyCalorieGoal
        self.preferredWorkoutTypes = preferredWorkoutTypes
        self.reminderTime = reminderTime
        self.enableNotifications = enableNotifications
    }
}
