//
//  WatchMessage.swift
//  GymJamShared
//
//  Shared message protocol for Watch ↔ iPhone communication.
//

import Foundation

// MARK: - Message Types

enum WatchMessageType: String, Codable {
    // iPhone → Watch
    case sessionStateUpdate
    case restTimerTick
    case sessionEnded
    case todayPlanUpdate

    // Watch → iPhone
    case completeSet
    case startCardio
    case completeCardio
    case restTimerAction
    case requestSessionStart
    case heartRateBatch
    case workoutSummary
    /// Watch's HKWorkoutSession began — the phone must NOT save its own
    /// HKWorkout at completion (the Watch's builder writes the real one).
    case watchWorkoutStarted
}

// MARK: - Rest Timer Actions

enum WatchRestTimerAction: String, Codable {
    case skip
    case extend30
    case start
}

// MARK: - Message Keys

enum WatchMessageKey {
    static let type = "type"
    static let payload = "payload"

    // Set completion
    static let exerciseId = "exerciseId"
    static let setId = "setId"
    static let weight = "weight"
    static let reps = "reps"
    static let action = "action"

    // Cardio completion
    static let durationSeconds = "durationSeconds"
    static let distanceMeters = "distanceMeters"

    // Session ended: true = real completion (show summary), false = discard.
    static let sessionCompleted = "sessionCompleted"

    // Rest timer
    static let restAction = "restAction"
    static let restSeconds = "restSeconds"

    // Timer tick
    static let remaining = "remaining"

    // Session start request
    static let requestType = "requestType"
    static let planDayId = "planDayId"
}

// MARK: - Message Encoding/Decoding

enum WatchMessageCoder {

    static func encode(type: WatchMessageType, payload: Codable? = nil) -> [String: Any] {
        var message: [String: Any] = [WatchMessageKey.type: type.rawValue]
        if let payload = payload, let data = try? JSONEncoder().encode(payload) {
            message[WatchMessageKey.payload] = data
        }
        return message
    }

    static func encodeSetCompletion(exerciseId: String, setId: String, weight: Double?, reps: Int) -> [String: Any] {
        var message: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.completeSet.rawValue,
            WatchMessageKey.exerciseId: exerciseId,
            WatchMessageKey.setId: setId,
            WatchMessageKey.reps: reps
        ]
        if let weight = weight {
            message[WatchMessageKey.weight] = weight
        }
        return message
    }

    static func encodeStartCardio(exerciseId: String) -> [String: Any] {
        [
            WatchMessageKey.type: WatchMessageType.startCardio.rawValue,
            WatchMessageKey.exerciseId: exerciseId,
        ]
    }

    static func encodeCardioCompletion(exerciseId: String, durationSeconds: Int, distanceMeters: Int?) -> [String: Any] {
        var message: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.completeCardio.rawValue,
            WatchMessageKey.exerciseId: exerciseId,
            WatchMessageKey.durationSeconds: durationSeconds,
        ]
        if let distanceMeters { message[WatchMessageKey.distanceMeters] = distanceMeters }
        return message
    }

    static func encodeRestTimerAction(_ action: WatchRestTimerAction) -> [String: Any] {
        [
            WatchMessageKey.type: WatchMessageType.restTimerAction.rawValue,
            WatchMessageKey.restAction: action.rawValue
        ]
    }

    static func encodeRequestSessionStart(requestType: String, planDayId: String? = nil) -> [String: Any] {
        var message: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.requestSessionStart.rawValue,
            WatchMessageKey.requestType: requestType
        ]
        if let planDayId {
            message[WatchMessageKey.planDayId] = planDayId
        }
        return message
    }

    static func encodeRestTimerTick(remaining: Int) -> [String: Any] {
        [
            WatchMessageKey.type: WatchMessageType.restTimerTick.rawValue,
            WatchMessageKey.remaining: remaining
        ]
    }

    static func decodeType(from message: [String: Any]) -> WatchMessageType? {
        guard let raw = message[WatchMessageKey.type] as? String else { return nil }
        return WatchMessageType(rawValue: raw)
    }

    static func decodePayload<T: Decodable>(_ type: T.Type, from message: [String: Any]) -> T? {
        guard let data = message[WatchMessageKey.payload] as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
