//
//  MockHealthKitService.swift
//  GymBroTests
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import HealthKit
@testable import GymJam

/// Mock implementation of HealthKitServiceProtocol for testing
final class MockHealthKitService: HealthKitServiceProtocol {

    // MARK: - Mock Configuration

    var shouldFail = false
    var errorToThrow: HealthKitError = .notAvailable
    var isHealthDataAvailable: Bool = true

    // MARK: - Mock Data

    private var mockWorkouts: [WorkoutData] = []
    private var mockHeartRateSamples: [HealthSample] = []
    private var mockActiveEnergySamples: [HealthSample] = []
    private var mockWeightSamples: [HealthSample] = []
    private var mockBodyFatSamples: [HealthSample] = []
    private var mockLeanMassSamples: [HealthSample] = []

    // MARK: - Tracking

    private(set) var requestAuthorizationCallCount = 0
    private(set) var saveWorkoutCallCount = 0
    private(set) var deleteWorkoutCallCount = 0
    private(set) var fetchWorkoutsCallCount = 0
    private(set) var saveHeartRateCallCount = 0
    private(set) var saveWeightCallCount = 0

    // MARK: - Authorization

    func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1

        if shouldFail {
            throw errorToThrow
        }
    }

    // MARK: - Workouts

    func saveWorkout(_ workout: WorkoutData) async throws {
        saveWorkoutCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        mockWorkouts.append(workout)
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData] {
        fetchWorkoutsCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        return mockWorkouts.filter { workout in
            workout.startDate >= startDate && workout.endDate <= endDate
        }
    }

    func deleteWorkout(workoutId: UUID) async throws {
        deleteWorkoutCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        mockWorkouts.removeAll { $0.id == workoutId }
    }

    // MARK: - Heart Rate

    func fetchHeartRate(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        if shouldFail {
            throw errorToThrow
        }

        return mockHeartRateSamples.filter { sample in
            sample.startDate >= startDate && sample.endDate <= endDate
        }
    }

    func saveHeartRate(_ heartRate: Double, date: Date) async throws {
        saveHeartRateCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        let sample = HealthSample(
            value: heartRate,
            unit: "bpm",
            startDate: date
        )
        mockHeartRateSamples.append(sample)
    }

    func fetchAverageHeartRate(from startDate: Date, to endDate: Date) async throws -> Double? {
        if shouldFail {
            throw errorToThrow
        }

        let samples = try await fetchHeartRate(from: startDate, to: endDate)
        guard !samples.isEmpty else { return nil }

        let total = samples.reduce(0.0) { $0 + $1.value }
        return total / Double(samples.count)
    }

    var mockRestingHeartRate: Double?

    func fetchRestingHeartRate() async throws -> Double? {
        if shouldFail {
            throw errorToThrow
        }
        return mockRestingHeartRate
    }

    // MARK: - Active Energy

    func fetchActiveEnergy(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        if shouldFail {
            throw errorToThrow
        }

        return mockActiveEnergySamples.filter { sample in
            sample.startDate >= startDate && sample.endDate <= endDate
        }
    }

    func saveActiveEnergy(_ energy: Double, from startDate: Date, to endDate: Date) async throws {
        if shouldFail {
            throw errorToThrow
        }

        let sample = HealthSample(
            value: energy,
            unit: "kcal",
            startDate: startDate,
            endDate: endDate
        )
        mockActiveEnergySamples.append(sample)
    }

    func fetchTotalActiveEnergy(from startDate: Date, to endDate: Date) async throws -> Double {
        if shouldFail {
            throw errorToThrow
        }

        let samples = try await fetchActiveEnergy(from: startDate, to: endDate)
        return samples.reduce(0.0) { $0 + $1.value }
    }

    // MARK: - Body Measurements

    func saveWeight(_ weight: Double, date: Date) async throws {
        saveWeightCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        let sample = HealthSample(
            value: weight,
            unit: "kg",
            startDate: date
        )
        mockWeightSamples.append(sample)
    }

    func fetchWeight(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        if shouldFail {
            throw errorToThrow
        }

        return mockWeightSamples.filter { sample in
            sample.startDate >= startDate && sample.endDate <= endDate
        }
    }

    func fetchLatestWeight() async throws -> HealthSample? {
        if shouldFail {
            throw errorToThrow
        }

        return mockWeightSamples.last
    }

    func fetchLatestHeight() async throws -> HealthSample? {
        if shouldFail {
            throw errorToThrow
        }

        return nil
    }

    func fetchBiologicalSex() -> HKBiologicalSex? {
        nil
    }

    func saveBodyFatPercentage(_ bodyFat: Double, date: Date) async throws {
        if shouldFail {
            throw errorToThrow
        }

        let sample = HealthSample(
            value: bodyFat,
            unit: "%",
            startDate: date
        )
        mockBodyFatSamples.append(sample)
    }

    func fetchBodyFatPercentage(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        if shouldFail {
            throw errorToThrow
        }

        return mockBodyFatSamples.filter { sample in
            sample.startDate >= startDate && sample.endDate <= endDate
        }
    }

    func saveLeanBodyMass(_ leanMass: Double, date: Date) async throws {
        if shouldFail {
            throw errorToThrow
        }

        let sample = HealthSample(
            value: leanMass,
            unit: "kg",
            startDate: date
        )
        mockLeanMassSamples.append(sample)
    }

    func fetchLeanBodyMass(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        if shouldFail {
            throw errorToThrow
        }

        return mockLeanMassSamples.filter { sample in
            sample.startDate >= startDate && sample.endDate <= endDate
        }
    }

    // MARK: - Dashboard Stats

    var mockBodyFat: Double?
    var mockLeanBodyMass: Double?
    var mockStepCount: Double?
    var mockSleepDuration: Double?
    var mockHRV: Double?
    var mockVO2Max: Double?
    var mockWalkingDistance: Double?

    func fetchLatestBodyFat() async throws -> Double? {
        if shouldFail { throw errorToThrow }
        return mockBodyFat
    }

    func fetchLatestLeanBodyMass() async throws -> Double? {
        if shouldFail { throw errorToThrow }
        return mockLeanBodyMass
    }

    func fetchTodayStepCount() async throws -> Double? {
        if shouldFail { throw errorToThrow }
        return mockStepCount
    }

    func fetchLastNightSleepDuration() async throws -> Double? {
        if shouldFail { throw errorToThrow }
        return mockSleepDuration
    }

    func fetchLatestHRV() async throws -> Double? {
        if shouldFail { throw errorToThrow }
        return mockHRV
    }

    func fetchLatestVO2Max() async throws -> Double? {
        if shouldFail { throw errorToThrow }
        return mockVO2Max
    }

    func fetchTodayWalkingDistance() async throws -> Double? {
        if shouldFail { throw errorToThrow }
        return mockWalkingDistance
    }

    // MARK: - Helper Methods

    func addMockWorkout(_ workout: WorkoutData) {
        mockWorkouts.append(workout)
    }

    func addMockHeartRateSample(_ sample: HealthSample) {
        mockHeartRateSamples.append(sample)
    }

    func reset() {
        mockWorkouts.removeAll()
        mockHeartRateSamples.removeAll()
        mockActiveEnergySamples.removeAll()
        mockWeightSamples.removeAll()
        mockBodyFatSamples.removeAll()
        mockLeanMassSamples.removeAll()

        requestAuthorizationCallCount = 0
        saveWorkoutCallCount = 0
        deleteWorkoutCallCount = 0
        fetchWorkoutsCallCount = 0
        saveHeartRateCallCount = 0
        saveWeightCallCount = 0

        shouldFail = false
        isHealthDataAvailable = true
    }
}
