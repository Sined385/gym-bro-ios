//
//  WorkoutActivityAttributes.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-07.
//

import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    let sessionTitle: String
    let sessionStartDate: Date

    struct ContentState: Codable, Hashable {
        let isResting: Bool
        let restEndDate: Date?
        let lastExerciseName: String?
        let lastSetDisplay: String?     // "60kg × 10"
        let totalSetsCompleted: Int
        let totalExercises: Int
    }
}
