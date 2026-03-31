//
//  ProgressGoalModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import SwiftData

/// SwiftData model for tracking fitness goals and progress
@Model
final class ProgressGoalModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var goalDescription: String?
    var goalType: String // "weight", "workout_frequency", "strength", "endurance", "custom"
    var targetValue: Double
    var currentValue: Double
    var unit: String
    var startDate: Date
    var targetDate: Date?
    var isCompleted: Bool
    var completedDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        goalDescription: String? = nil,
        goalType: String,
        targetValue: Double,
        currentValue: Double = 0,
        unit: String,
        startDate: Date = Date(),
        targetDate: Date? = nil,
        isCompleted: Bool = false,
        completedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.goalType = goalType
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.startDate = startDate
        self.targetDate = targetDate
        self.isCompleted = isCompleted
        self.completedDate = completedDate
    }

    /// Calculate progress as a percentage (0-100)
    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min((currentValue / targetValue) * 100, 100)
    }

    /// Check if goal is achieved
    func checkAndUpdateCompletion() {
        if currentValue >= targetValue && !isCompleted {
            isCompleted = true
            completedDate = Date()
        }
    }
}
