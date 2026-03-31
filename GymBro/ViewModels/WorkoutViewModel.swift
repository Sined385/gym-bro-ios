//
//  WorkoutViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import Combine
import HealthKit
import SwiftData

/// ViewModel for managing workout data and interactions
@MainActor
final class WorkoutViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var workouts: [WorkoutData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isHealthKitAuthorized = false

    // Current workout tracking
    @Published var currentWorkout: WorkoutData?
    @Published var isWorkoutInProgress = false

    // Statistics
    @Published var totalWorkoutsThisWeek: Int = 0
    @Published var totalCaloriesBurnedThisWeek: Double = 0
    @Published var averageHeartRate: Double?

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let healthKitService: HealthKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        networkService: NetworkServiceProtocol,
        healthKitService: HealthKitServiceProtocol
    ) {
        self.networkService = networkService
        self.healthKitService = healthKitService
    }

    // MARK: - HealthKit Authorization

    func requestHealthKitAuthorization() async {
        guard healthKitService.isHealthDataAvailable else {
            errorMessage = "HealthKit is not available on this device"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await healthKitService.requestAuthorization()
            isHealthKitAuthorized = true
            await loadWorkouts()
            await loadStatistics()
        } catch {
            errorMessage = "Failed to authorize HealthKit: \(error.localizedDescription)"
            isHealthKitAuthorized = false
        }

        isLoading = false
    }

    // MARK: - Workout Management

    /// Loads workouts from HealthKit for the current week
    func loadWorkouts() async {
        isLoading = true
        errorMessage = nil

        do {
            let calendar = Calendar.current
            let now = Date()
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
                throw HealthKitError.invalidData
            }

            workouts = try await healthKitService.fetchWorkouts(from: weekStart, to: now)
            totalWorkoutsThisWeek = workouts.count

            // Calculate total calories burned
            totalCaloriesBurnedThisWeek = workouts.compactMap { $0.totalEnergyBurned }.reduce(0, +)
        } catch {
            errorMessage = "Failed to load workouts: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Starts a new workout session
    func startWorkout(type: HKWorkoutActivityType) {
        currentWorkout = WorkoutData(
            activityType: type,
            startDate: Date(),
            endDate: Date(), // Will be updated when workout ends
            duration: 0
        )
        isWorkoutInProgress = true
    }

    /// Ends the current workout and saves it
    func endWorkout() async {
        guard var workout = currentWorkout else {
            errorMessage = "No workout in progress"
            return
        }

        isLoading = true
        errorMessage = nil

        // Update end date
        let endDate = Date()
        workout = WorkoutData(
            id: workout.id,
            activityType: workout.activityType,
            startDate: workout.startDate,
            endDate: endDate,
            duration: endDate.timeIntervalSince(workout.startDate),
            totalEnergyBurned: workout.totalEnergyBurned,
            totalDistance: workout.totalDistance,
            metadata: workout.metadata
        )

        do {
            // Save to HealthKit
            try await healthKitService.saveWorkout(workout)

            // Sync to backend
            await syncWorkoutToBackend(workout)

            // Reload workouts
            await loadWorkouts()

            // Clear current workout
            currentWorkout = nil
            isWorkoutInProgress = false
        } catch {
            errorMessage = "Failed to save workout: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Deletes a workout
    func deleteWorkout(_ workout: WorkoutData) async {
        isLoading = true
        errorMessage = nil

        do {
            try await healthKitService.deleteWorkout(workoutId: workout.id)
            await loadWorkouts()
        } catch {
            errorMessage = "Failed to delete workout: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Statistics

    /// Loads workout statistics
    func loadStatistics() async {
        isLoading = true
        errorMessage = nil

        do {
            let calendar = Calendar.current
            let now = Date()
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
                throw HealthKitError.invalidData
            }

            // Fetch average heart rate
            averageHeartRate = try await healthKitService.fetchAverageHeartRate(from: weekStart, to: now)

            // Total calories already calculated in loadWorkouts
        } catch {
            errorMessage = "Failed to load statistics: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Refreshes all data
    func refresh() async {
        await loadWorkouts()
        await loadStatistics()
    }

    // MARK: - Backend Sync

    /// Syncs workout to backend API
    private func syncWorkoutToBackend(_ workout: WorkoutData) async {
        // Example of how to sync to backend
        // This demonstrates the network service usage

        do {
            let endpoint = WorkoutRouter.sync(
                workoutId: workout.id.uuidString,
                activityType: workout.activityType.rawValue,
                startDate: ISO8601DateFormatter().string(from: workout.startDate),
                endDate: ISO8601DateFormatter().string(from: workout.endDate),
                duration: workout.duration,
                totalEnergyBurned: workout.totalEnergyBurned,
                totalDistance: workout.totalDistance
            ).endpoint

            // Uncomment when backend is ready
            // try await networkService.request(endpoint)
        } catch {
            // Log error but don't show to user - sync is not critical
            print("Failed to sync workout to backend: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    /// Formats duration for display
    func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Formats calories for display
    func formattedCalories(_ calories: Double?) -> String {
        guard let calories = calories else { return "N/A" }
        return String(format: "%.0f kcal", calories)
    }
}
