//
//  HealthKitServiceProtocol.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import HealthKit

/// Protocol defining HealthKit service capabilities for testability
protocol HealthKitServiceProtocol: AnyObject {

    // MARK: - Authorization

    /// Requests authorization for all required HealthKit data types
    func requestAuthorization() async throws

    /// Checks if HealthKit is available on the device
    var isHealthDataAvailable: Bool { get }

    // MARK: - Workouts

    /// Saves a workout to HealthKit
    /// - Parameter workout: The workout data to save
    func saveWorkout(_ workout: WorkoutData) async throws

    /// Fetches workouts within a date range
    /// - Parameters:
    ///   - startDate: Start date for the query
    ///   - endDate: End date for the query
    /// - Returns: Array of workout data
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData]

    /// Deletes a workout from HealthKit
    /// - Parameter workoutId: The UUID of the workout to delete
    func deleteWorkout(workoutId: UUID) async throws

    // MARK: - Heart Rate

    /// Fetches heart rate samples within a date range
    /// - Parameters:
    ///   - startDate: Start date for the query
    ///   - endDate: End date for the query
    /// - Returns: Array of heart rate samples
    func fetchHeartRate(from startDate: Date, to endDate: Date) async throws -> [HealthSample]

    /// Saves a heart rate measurement
    /// - Parameter heartRate: Heart rate in beats per minute
    /// - Parameter date: The date of the measurement
    func saveHeartRate(_ heartRate: Double, date: Date) async throws

    /// Fetches the average heart rate for a date range
    /// - Parameters:
    ///   - startDate: Start date for the query
    ///   - endDate: End date for the query
    /// - Returns: Average heart rate in beats per minute
    func fetchAverageHeartRate(from startDate: Date, to endDate: Date) async throws -> Double?

    // MARK: - Active Energy

    /// Fetches active energy burned within a date range
    /// - Parameters:
    ///   - startDate: Start date for the query
    ///   - endDate: End date for the query
    /// - Returns: Array of active energy samples
    func fetchActiveEnergy(from startDate: Date, to endDate: Date) async throws -> [HealthSample]

    /// Saves active energy burned
    /// - Parameters:
    ///   - energy: Energy in kilocalories
    ///   - startDate: Start time of the activity
    ///   - endDate: End time of the activity
    func saveActiveEnergy(_ energy: Double, from startDate: Date, to endDate: Date) async throws

    /// Fetches total active energy burned for a date range
    /// - Parameters:
    ///   - startDate: Start date for the query
    ///   - endDate: End date for the query
    /// - Returns: Total active energy in kilocalories
    func fetchTotalActiveEnergy(from startDate: Date, to endDate: Date) async throws -> Double

    // MARK: - Body Measurements

    /// Saves body weight measurement
    /// - Parameters:
    ///   - weight: Weight in kilograms
    ///   - date: The date of the measurement
    func saveWeight(_ weight: Double, date: Date) async throws

    /// Fetches weight measurements within a date range
    /// - Parameters:
    ///   - startDate: Start date for the query
    ///   - endDate: End date for the query
    /// - Returns: Array of weight samples
    func fetchWeight(from startDate: Date, to endDate: Date) async throws -> [HealthSample]

    /// Fetches the most recent weight measurement
    /// - Returns: The most recent weight sample
    func fetchLatestWeight() async throws -> HealthSample?

    /// Fetches the most recent height measurement
    /// - Returns: The most recent height sample
    func fetchLatestHeight() async throws -> HealthSample?

    /// Fetches the user's biological sex from HealthKit characteristics
    /// - Returns: Biological sex value, or nil if not set/authorized
    func fetchBiologicalSex() -> HKBiologicalSex?

    /// Saves body fat percentage
    /// - Parameters:
    ///   - bodyFat: Body fat percentage (0-100)
    ///   - date: The date of the measurement
    func saveBodyFatPercentage(_ bodyFat: Double, date: Date) async throws

    /// Fetches body fat percentage measurements
    /// - Parameters:
    ///   - startDate: Start date for the query
    ///   - endDate: End date for the query
    /// - Returns: Array of body fat samples
    func fetchBodyFatPercentage(from startDate: Date, to endDate: Date) async throws -> [HealthSample]

    /// Saves lean body mass
    /// - Parameters:
    ///   - leanMass: Lean body mass in kilograms
    ///   - date: The date of the measurement
    func saveLeanBodyMass(_ leanMass: Double, date: Date) async throws

    /// Fetches lean body mass measurements
    /// - Parameters:
    ///   - startDate: Start date for the query
    ///   - endDate: End date for the query
    /// - Returns: Array of lean body mass samples
    func fetchLeanBodyMass(from startDate: Date, to endDate: Date) async throws -> [HealthSample]
}

// MARK: - Supporting Data Models

/// Represents a workout session
struct WorkoutData {
    let id: UUID
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalEnergyBurned: Double? // in kilocalories
    let totalDistance: Double? // in meters
    let metadata: [String: Any]?

    init(
        id: UUID = UUID(),
        activityType: HKWorkoutActivityType,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval? = nil,
        totalEnergyBurned: Double? = nil,
        totalDistance: Double? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration ?? endDate.timeIntervalSince(startDate)
        self.totalEnergyBurned = totalEnergyBurned
        self.totalDistance = totalDistance
        self.metadata = metadata
    }
}

/// Represents a generic health sample (heart rate, energy, weight, etc.)
struct HealthSample {
    let id: UUID
    let value: Double
    let unit: String
    let startDate: Date
    let endDate: Date

    init(
        id: UUID = UUID(),
        value: Double,
        unit: String,
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.id = id
        self.value = value
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate ?? startDate
    }
}

/// Errors that can occur during HealthKit operations
enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case noData
    case invalidData
    case saveFailed(Error)
    case queryFailed(Error)
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .noData:
            return "No health data available"
        case .invalidData:
            return "Invalid health data"
        case .saveFailed(let error):
            return "Failed to save health data: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "Failed to query health data: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete health data: \(error.localizedDescription)"
        }
    }
}
