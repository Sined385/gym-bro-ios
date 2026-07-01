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
    /// Phone-driven override: when the user has a specific exercise open on
    /// the phone screen, the phone sets this to that exercise's id and the
    /// Watch follows. When nil (no specific view open), Watch falls back to
    /// the "first incomplete" heuristic so watch-only flow stays natural.
    var activeExerciseId: String?
    // Cardio recording mirror (phone is source of truth). Lets the Watch
    // reflect a walk started/stopped on the phone and run a matching live
    // timer between pushes. All optional so older payloads still decode.
    var cardioRecordingExerciseId: String?
    /// Wall-clock the current unpaused run started; nil while paused.
    var cardioRecordingStartDate: Date?
    /// Seconds banked from prior unpaused runs.
    var cardioRecordingAccumulatedSeconds: Int?

    func isRecordingCardio(_ exerciseId: String) -> Bool {
        cardioRecordingExerciseId == exerciseId
    }

    /// Live elapsed for the recorded cardio at `now` — mirrors the phone's
    /// `currentCardioElapsed`: banked seconds + (now − start) when running.
    func cardioElapsed(at now: Date) -> Int {
        let banked = cardioRecordingAccumulatedSeconds ?? 0
        if let start = cardioRecordingStartDate {
            return max(0, banked + Int(now.timeIntervalSince(start)))
        }
        return banked
    }

    var currentExercise: WatchExerciseState? {
        if let pinned = activeExerciseId,
           let match = exercises.first(where: { $0.id == pinned }) {
            return match
        }
        return exercises.first { exercise in
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
    /// Cardio exercises (walking/running/etc.) are time-based, not set/rep
    /// based — the Watch shows a Start→timer→Done flow instead of set rows.
    /// Optional so older payloads still decode; treat nil as false.
    let isCardio: Bool?

    var isCardioExercise: Bool { isCardio == true }

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
    /// Set for completed cardio sets so the Watch can show the final time.
    let durationSeconds: Int?
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
