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

        // Cardio recording (walking, rowing, …). Without these the
        // activity for a cardio-only session had nothing to show —
        // no sets, no rest — just an empty card.
        /// Name of the cardio exercise being recorded, nil when none.
        let cardioExerciseName: String?
        /// Anchor date such that (now − anchor) == elapsed. The widget
        /// renders it with `style: .timer` so it ticks without updates.
        /// Nil while paused (or when no cardio is recording).
        let cardioAnchorDate: Date?
        /// Frozen elapsed seconds while paused. Nil unless paused.
        let cardioPausedElapsedSeconds: Int?

        init(
            isResting: Bool,
            restEndDate: Date?,
            lastExerciseName: String?,
            lastSetDisplay: String?,
            totalSetsCompleted: Int,
            totalExercises: Int,
            cardioExerciseName: String? = nil,
            cardioAnchorDate: Date? = nil,
            cardioPausedElapsedSeconds: Int? = nil
        ) {
            self.isResting = isResting
            self.restEndDate = restEndDate
            self.lastExerciseName = lastExerciseName
            self.lastSetDisplay = lastSetDisplay
            self.totalSetsCompleted = totalSetsCompleted
            self.totalExercises = totalExercises
            self.cardioExerciseName = cardioExerciseName
            self.cardioAnchorDate = cardioAnchorDate
            self.cardioPausedElapsedSeconds = cardioPausedElapsedSeconds
        }

        var isCardioActive: Bool {
            cardioExerciseName != nil
        }
    }
}
