//
//  WatchSessionState.swift
//  GymJamShared
//
//  Transfer payloads for Watch ↔ iPhone communication.
//

import Foundation

// MARK: - Session State (iPhone → Watch)

struct WatchSessionState: Codable {
    let sessionId: String
    let sessionTitle: String
    let elapsedSeconds: Int
    let sessionStartDate: Date
    let exercises: [WatchExerciseState]
    let isResting: Bool
    let restTimeRemaining: Int?
    let restStartDate: Date?
    let restDurationSeconds: Int

    var currentExercise: WatchExerciseState? {
        exercises.first { exercise in
            exercise.sets.contains { !$0.isCompleted }
        } ?? exercises.last
    }

    var totalSetsCompleted: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}

// MARK: - Exercise State

struct WatchExerciseState: Codable, Identifiable {
    let id: String
    let name: String
    let muscleGroup: String
    let equipment: String
    let sets: [WatchSetState]
    let supersetGroupId: String?
    let supersetOrder: String?
    let targetSets: Int
    let targetReps: Int

    var completedSetsCount: Int {
        sets.filter(\.isCompleted).count
    }

    var currentSet: WatchSetState? {
        sets.first { !$0.isCompleted }
    }

    var isComplete: Bool {
        !sets.isEmpty && sets.allSatisfy(\.isCompleted)
    }
}

// MARK: - Set State

struct WatchSetState: Codable, Identifiable {
    let id: String
    let setNumber: Int
    let weight: Double?
    let weightUnit: String
    let reps: Int?
    let isCompleted: Bool
}

// MARK: - Today Plan (iPhone → Watch)

struct WatchTodayPlan: Codable {
    let dayLabel: String
    let sessionTitle: String?
    let dayType: String
    let muscleGroups: [String]
    let exercises: [WatchPlanExercise]
    let planDayId: String?
}

struct WatchPlanExercise: Codable, Identifiable {
    let name: String
    let muscleGroup: String
    let setsDisplay: String
    var id: String { name + setsDisplay }
}

// MARK: - Workout Summary (Watch → iPhone)

struct WatchWorkoutSummary: Codable {
    let totalDurationSeconds: Int
    let activeCalories: Double
    let averageHeartRate: Double?
    let maxHeartRate: Double?

    var durationMinutes: Int {
        totalDurationSeconds / 60
    }
}

// MARK: - Heart Rate Batch (Watch → iPhone)

struct WatchHeartRateBatch: Codable {
    let samples: [WatchHeartRateSample]
}

struct WatchHeartRateSample: Codable {
    let bpm: Double
    let timestamp: Date
}
