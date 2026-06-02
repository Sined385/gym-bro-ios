//
//  SessionCompletionCacheService.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-23.
//

import Foundation

// MARK: - Codable Payload Models

struct CompletionSet: Codable {
    let setNumber: Int
    let reps: Int
    let isCompleted: Bool
    let weight: Double?
    let weightUnit: String
    let isBodyweight: Bool

    enum CodingKeys: String, CodingKey {
        case setNumber = "set_number"
        case reps
        case isCompleted = "is_completed"
        case weight
        case weightUnit = "weight_unit"
        case isBodyweight = "is_bodyweight"
    }

    init(setNumber: Int, reps: Int, isCompleted: Bool, weight: Double?, weightUnit: String, isBodyweight: Bool = false) {
        self.setNumber = setNumber
        self.reps = reps
        self.isCompleted = isCompleted
        self.weight = weight
        self.weightUnit = weightUnit
        self.isBodyweight = isBodyweight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.setNumber = try c.decode(Int.self, forKey: .setNumber)
        self.reps = try c.decode(Int.self, forKey: .reps)
        self.isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        self.weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        self.weightUnit = try c.decodeIfPresent(String.self, forKey: .weightUnit) ?? "kg"
        // Default false so previously-cached PendingSessionCompletion blobs
        // (queued before this field existed) decode and replay safely.
        self.isBodyweight = try c.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
    }
}

struct CompletionExercise: Codable {
    let name: String
    let muscleGroup: String
    let stepNumber: Int
    let sets: [CompletionSet]
    let libraryExerciseId: String?
    let equipment: String?
    let accentColor: String?
    let supersetGroupId: String?
    let supersetOrder: String?

    enum CodingKeys: String, CodingKey {
        case name
        case muscleGroup = "muscle_group"
        case stepNumber = "step_number"
        case sets
        case libraryExerciseId = "library_exercise_id"
        case equipment
        case accentColor = "accent_color"
        case supersetGroupId = "superset_group_id"
        case supersetOrder = "superset_order"
    }
}

struct SessionFeedback: Codable {
    let effortLevel: Int
    let energyLevel: Int
    let painDiscomfort: String

    enum CodingKeys: String, CodingKey {
        case effortLevel = "effort_level"
        case energyLevel = "energy_level"
        case painDiscomfort = "pain_discomfort"
    }
}

struct SessionCompletionPayload: Codable {
    let durationMinutes: Int
    /// Apple Watch / HealthKit-derived average heart rate over the session.
    /// Nil when the user wasn't wearing a watch — keeps the field optional
    /// end-to-end so old cached payloads decode and the API accepts both.
    let avgHeartRate: Int?
    let feedback: SessionFeedback
    let exercises: [CompletionExercise]

    enum CodingKeys: String, CodingKey {
        case durationMinutes = "duration_minutes"
        case avgHeartRate = "avg_heart_rate"
        case feedback
        case exercises
    }

    init(
        durationMinutes: Int,
        avgHeartRate: Int? = nil,
        feedback: SessionFeedback,
        exercises: [CompletionExercise]
    ) {
        self.durationMinutes = durationMinutes
        self.avgHeartRate = avgHeartRate
        self.feedback = feedback
        self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.durationMinutes = try c.decode(Int.self, forKey: .durationMinutes)
        self.avgHeartRate = try c.decodeIfPresent(Int.self, forKey: .avgHeartRate)
        self.feedback = try c.decode(SessionFeedback.self, forKey: .feedback)
        self.exercises = try c.decode([CompletionExercise].self, forKey: .exercises)
    }

    func toDictionary() -> [String: Any] {
        var root: [String: Any] = [
            "duration_minutes": durationMinutes,
            "feedback": [
                "effort_level": feedback.effortLevel,
                "energy_level": feedback.energyLevel,
                "pain_discomfort": feedback.painDiscomfort
            ],
            "exercises": exercises.map { ex -> [String: Any] in
                var dict: [String: Any] = [
                    "name": ex.name,
                    "muscle_group": ex.muscleGroup,
                    "step_number": ex.stepNumber,
                    "sets": ex.sets.map { set -> [String: Any] in
                        var setDict: [String: Any] = [
                            "set_number": set.setNumber,
                            "reps": set.reps,
                            "is_completed": set.isCompleted,
                            "is_bodyweight": set.isBodyweight
                        ]
                        if let weight = set.weight, !set.isBodyweight { setDict["weight"] = weight }
                        setDict["weight_unit"] = set.weightUnit
                        return setDict
                    }
                ]
                if let libId = ex.libraryExerciseId { dict["library_exercise_id"] = libId }
                if let equipment = ex.equipment { dict["equipment"] = equipment }
                if let color = ex.accentColor { dict["accent_color"] = color }
                if let groupId = ex.supersetGroupId { dict["superset_group_id"] = groupId }
                if let order = ex.supersetOrder { dict["superset_order"] = order }
                return dict
            }
        ]
        if let avgHeartRate { root["avg_heart_rate"] = avgHeartRate }
        return root
    }
}

// MARK: - Pending Completion Wrapper

struct PendingSessionCompletion: Codable {
    let id: UUID
    let sessionId: String
    let sessionTitle: String
    let payload: SessionCompletionPayload
    let createdAt: Date
    var retryCount: Int
    var lastRetryAt: Date?
}

// MARK: - Protocol

protocol SessionCompletionCacheServiceProtocol: AnyObject {
    func save(_ completion: PendingSessionCompletion)
    func loadAll() -> [PendingSessionCompletion]
    func remove(id: UUID)
    func retryPendingCompletions() async
}

// MARK: - Implementation

final class SessionCompletionCacheService: SessionCompletionCacheServiceProtocol {

    private let networkService: NetworkServiceProtocol
    private let appDataState: AppDataState
    private let directory: URL
    private let maxRetries = 20
    private var isRetrying = false

    init(networkService: NetworkServiceProtocol, appDataState: AppDataState) {
        self.networkService = networkService
        self.appDataState = appDataState

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.directory = appSupport.appendingPathComponent("PendingCompletions", isDirectory: true)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    func save(_ completion: PendingSessionCompletion) {
        do {
            let data = try JSONEncoder().encode(completion)
            try data.write(to: fileURL(for: completion.id), options: .atomic)
        } catch {
            print("Failed to save pending completion: \(error)")
        }
    }

    func loadAll() -> [PendingSessionCompletion] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.compactMap { url -> PendingSessionCompletion? in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(PendingSessionCompletion.self, from: data)
        }.sorted { $0.createdAt < $1.createdAt }
    }

    func remove(id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    func retryPendingCompletions() async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }

        let pending = loadAll()
        guard !pending.isEmpty else { return }

        for var item in pending {
            // Exponential backoff: skip if not enough time has passed
            let backoffSeconds = min(pow(2.0, Double(item.retryCount)) * 30, 3600)
            if let lastRetry = item.lastRetryAt,
               Date().timeIntervalSince(lastRetry) < backoffSeconds {
                continue
            }

            // Give up after max retries
            if item.retryCount >= maxRetries {
                remove(id: item.id)
                continue
            }

            let payload = item.payload.toDictionary()

            do {
                _ = try await networkService.request(
                    SessionRouter.completeSessionFull(sessionId: item.sessionId, payload: payload).endpoint,
                    responseType: SessionResponse.self
                )
                // Success — remove cached file and trigger reload
                remove(id: item.id)
                await MainActor.run {
                    appDataState.triggerReload()
                }
            } catch {
                let shouldRemove = isTerminalError(error)
                if shouldRemove {
                    remove(id: item.id)
                } else {
                    // Increment retry and save
                    item.retryCount += 1
                    item.lastRetryAt = Date()
                    save(item)
                }
            }
        }
    }

    /// Returns true if the error means we should stop retrying (session already completed, deleted, etc.)
    private func isTerminalError(_ error: Error) -> Bool {
        guard let networkError = error as? NetworkError else { return false }
        switch networkError {
        case .statusCode(let code):
            // 400 = invalid_session_status (already completed) — idempotent success
            // 404 = session deleted
            return code == 400 || code == 404
        default:
            return false
        }
    }
}
