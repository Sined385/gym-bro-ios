//
//  HealthKitServiceTests.swift
//  GymBroTests
//
//  Created by Claude Code on 2026-03-12.
//

import Testing
import HealthKit
@testable import GymBro

@Suite("HealthKitService Tests")
struct HealthKitServiceTests {

    // MARK: - Authorization Tests

    @Test("Should request HealthKit authorization successfully")
    func testRequestAuthorization() async throws {
        let mockService = MockHealthKitService()

        try await mockService.requestAuthorization()

        #expect(mockService.requestAuthorizationCallCount == 1)
    }

    @Test("Should throw error when HealthKit not available")
    func testAuthorizationFailure() async {
        let mockService = MockHealthKitService()
        mockService.shouldFail = true
        mockService.errorToThrow = .notAvailable

        await #expect(throws: HealthKitError.self) {
            try await mockService.requestAuthorization()
        }
    }

    // MARK: - Workout Tests

    @Test("Should save workout successfully")
    func testSaveWorkout() async throws {
        let mockService = MockHealthKitService()

        let workout = WorkoutData(
            activityType: .running,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            totalEnergyBurned: 300
        )

        try await mockService.saveWorkout(workout)

        #expect(mockService.saveWorkoutCallCount == 1)
    }

    @Test("Should fetch workouts within date range")
    func testFetchWorkouts() async throws {
        let mockService = MockHealthKitService()

        let workout1 = WorkoutData(
            activityType: .running,
            startDate: Date().addingTimeInterval(-86400), // 1 day ago
            endDate: Date().addingTimeInterval(-82800),
            totalEnergyBurned: 300
        )

        let workout2 = WorkoutData(
            activityType: .cycling,
            startDate: Date().addingTimeInterval(-3600), // 1 hour ago
            endDate: Date(),
            totalEnergyBurned: 200
        )

        mockService.addMockWorkout(workout1)
        mockService.addMockWorkout(workout2)

        let workouts = try await mockService.fetchWorkouts(
            from: Date().addingTimeInterval(-172800), // 2 days ago
            to: Date()
        )

        #expect(workouts.count == 2)
        #expect(mockService.fetchWorkoutsCallCount == 1)
    }

    @Test("Should delete workout")
    func testDeleteWorkout() async throws {
        let mockService = MockHealthKitService()

        let workout = WorkoutData(
            activityType: .running,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600)
        )

        mockService.addMockWorkout(workout)

        let workoutsBefore = try await mockService.fetchWorkouts(
            from: Date().addingTimeInterval(-7200),
            to: Date().addingTimeInterval(7200)
        )
        #expect(workoutsBefore.count == 1)

        try await mockService.deleteWorkout(workoutId: workout.id)

        let workoutsAfter = try await mockService.fetchWorkouts(
            from: Date().addingTimeInterval(-7200),
            to: Date().addingTimeInterval(7200)
        )
        #expect(workoutsAfter.count == 0)
        #expect(mockService.deleteWorkoutCallCount == 1)
    }

    // MARK: - Heart Rate Tests

    @Test("Should save heart rate")
    func testSaveHeartRate() async throws {
        let mockService = MockHealthKitService()

        try await mockService.saveHeartRate(75.0, date: Date())

        #expect(mockService.saveHeartRateCallCount == 1)
    }

    @Test("Should fetch heart rate samples")
    func testFetchHeartRate() async throws {
        let mockService = MockHealthKitService()

        let sample = HealthSample(
            value: 75.0,
            unit: "bpm",
            startDate: Date()
        )
        mockService.addMockHeartRateSample(sample)

        let samples = try await mockService.fetchHeartRate(
            from: Date().addingTimeInterval(-3600),
            to: Date().addingTimeInterval(3600)
        )

        #expect(samples.count == 1)
        #expect(samples.first?.value == 75.0)
    }

    @Test("Should calculate average heart rate")
    func testAverageHeartRate() async throws {
        let mockService = MockHealthKitService()

        let sample1 = HealthSample(value: 70.0, unit: "bpm", startDate: Date().addingTimeInterval(-3600))
        let sample2 = HealthSample(value: 80.0, unit: "bpm", startDate: Date().addingTimeInterval(-1800))
        let sample3 = HealthSample(value: 75.0, unit: "bpm", startDate: Date())

        mockService.addMockHeartRateSample(sample1)
        mockService.addMockHeartRateSample(sample2)
        mockService.addMockHeartRateSample(sample3)

        let average = try await mockService.fetchAverageHeartRate(
            from: Date().addingTimeInterval(-7200),
            to: Date().addingTimeInterval(3600)
        )

        #expect(average == 75.0) // (70 + 80 + 75) / 3
    }

    // MARK: - Active Energy Tests

    @Test("Should save active energy")
    func testSaveActiveEnergy() async throws {
        let mockService = MockHealthKitService()

        try await mockService.saveActiveEnergy(
            300.0,
            from: Date(),
            to: Date().addingTimeInterval(3600)
        )

        let samples = try await mockService.fetchActiveEnergy(
            from: Date().addingTimeInterval(-1800),
            to: Date().addingTimeInterval(7200)
        )

        #expect(samples.count == 1)
        #expect(samples.first?.value == 300.0)
    }

    @Test("Should fetch total active energy")
    func testFetchTotalActiveEnergy() async throws {
        let mockService = MockHealthKitService()

        try await mockService.saveActiveEnergy(100.0, from: Date(), to: Date().addingTimeInterval(1800))
        try await mockService.saveActiveEnergy(200.0, from: Date().addingTimeInterval(1800), to: Date().addingTimeInterval(3600))

        let total = try await mockService.fetchTotalActiveEnergy(
            from: Date().addingTimeInterval(-1800),
            to: Date().addingTimeInterval(7200)
        )

        #expect(total == 300.0)
    }

    // MARK: - Body Measurements Tests

    @Test("Should save weight")
    func testSaveWeight() async throws {
        let mockService = MockHealthKitService()

        try await mockService.saveWeight(75.5, date: Date())

        #expect(mockService.saveWeightCallCount == 1)
    }

    @Test("Should fetch weight samples")
    func testFetchWeight() async throws {
        let mockService = MockHealthKitService()

        try await mockService.saveWeight(75.5, date: Date())

        let samples = try await mockService.fetchWeight(
            from: Date().addingTimeInterval(-3600),
            to: Date().addingTimeInterval(3600)
        )

        #expect(samples.count == 1)
        #expect(samples.first?.value == 75.5)
    }

    @Test("Should fetch latest weight")
    func testFetchLatestWeight() async throws {
        let mockService = MockHealthKitService()

        try await mockService.saveWeight(75.0, date: Date().addingTimeInterval(-86400))
        try await mockService.saveWeight(74.5, date: Date())

        let latest = try await mockService.fetchLatestWeight()

        #expect(latest?.value == 74.5)
    }

    @Test("Should save and fetch body fat percentage")
    func testBodyFatPercentage() async throws {
        let mockService = MockHealthKitService()

        try await mockService.saveBodyFatPercentage(15.5, date: Date())

        let samples = try await mockService.fetchBodyFatPercentage(
            from: Date().addingTimeInterval(-3600),
            to: Date().addingTimeInterval(3600)
        )

        #expect(samples.count == 1)
        #expect(samples.first?.value == 15.5)
    }

    @Test("Should save and fetch lean body mass")
    func testLeanBodyMass() async throws {
        let mockService = MockHealthKitService()

        try await mockService.saveLeanBodyMass(65.0, date: Date())

        let samples = try await mockService.fetchLeanBodyMass(
            from: Date().addingTimeInterval(-3600),
            to: Date().addingTimeInterval(3600)
        )

        #expect(samples.count == 1)
        #expect(samples.first?.value == 65.0)
    }

    // MARK: - Error Handling Tests

    @Test("Should handle save errors")
    func testSaveError() async {
        let mockService = MockHealthKitService()
        mockService.shouldFail = true
        mockService.errorToThrow = .saveFailed(NSError(domain: "test", code: -1))

        await #expect(throws: HealthKitError.self) {
            try await mockService.saveWeight(75.0, date: Date())
        }
    }

    @Test("Should handle query errors")
    func testQueryError() async {
        let mockService = MockHealthKitService()
        mockService.shouldFail = true
        mockService.errorToThrow = .queryFailed(NSError(domain: "test", code: -1))

        await #expect(throws: HealthKitError.self) {
            try await mockService.fetchWorkouts(from: Date(), to: Date())
        }
    }
}
