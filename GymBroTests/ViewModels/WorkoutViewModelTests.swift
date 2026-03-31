//
//  WorkoutViewModelTests.swift
//  GymBroTests
//
//  Created by Claude Code on 2026-03-12.
//

import Testing
import HealthKit
@testable import GymBro

@Suite("WorkoutViewModel Tests")
@MainActor
struct WorkoutViewModelTests {

    // MARK: - Initialization Tests

    @Test("Should initialize with injected dependencies")
    func testInitialization() {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        #expect(viewModel.workouts.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Authorization Tests

    @Test("Should request HealthKit authorization")
    func testRequestAuthorization() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        await viewModel.requestHealthKitAuthorization()

        #expect(mockHealthKit.requestAuthorizationCallCount == 1)
        #expect(viewModel.isHealthKitAuthorized)
        #expect(!viewModel.isLoading)
    }

    @Test("Should handle authorization failure")
    func testAuthorizationFailure() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()
        mockHealthKit.shouldFail = true
        mockHealthKit.errorToThrow = .authorizationDenied

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        await viewModel.requestHealthKitAuthorization()

        #expect(!viewModel.isHealthKitAuthorized)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Failed to authorize") == true)
    }

    @Test("Should handle HealthKit not available")
    func testHealthKitNotAvailable() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()
        mockHealthKit.isHealthDataAvailable = false

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        await viewModel.requestHealthKitAuthorization()

        #expect(viewModel.errorMessage == "HealthKit is not available on this device")
    }

    // MARK: - Workout Loading Tests

    @Test("Should load workouts successfully")
    func testLoadWorkouts() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let workout1 = WorkoutData(
            activityType: .running,
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(-82800),
            totalEnergyBurned: 300
        )

        let workout2 = WorkoutData(
            activityType: .cycling,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            totalEnergyBurned: 200
        )

        mockHealthKit.addMockWorkout(workout1)
        mockHealthKit.addMockWorkout(workout2)

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        await viewModel.loadWorkouts()

        #expect(viewModel.workouts.count == 2)
        #expect(viewModel.totalWorkoutsThisWeek == 2)
        #expect(viewModel.totalCaloriesBurnedThisWeek == 500)
        #expect(!viewModel.isLoading)
    }

    @Test("Should handle load workouts failure")
    func testLoadWorkoutsFailure() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()
        mockHealthKit.shouldFail = true
        mockHealthKit.errorToThrow = .queryFailed(NSError(domain: "test", code: -1))

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        await viewModel.loadWorkouts()

        #expect(viewModel.workouts.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Failed to load workouts") == true)
    }

    // MARK: - Workout Management Tests

    @Test("Should start workout")
    func testStartWorkout() {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        viewModel.startWorkout(type: .running)

        #expect(viewModel.isWorkoutInProgress)
        #expect(viewModel.currentWorkout != nil)
        #expect(viewModel.currentWorkout?.activityType == .running)
    }

    @Test("Should end workout and save to HealthKit")
    func testEndWorkout() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        viewModel.startWorkout(type: .running)
        #expect(viewModel.isWorkoutInProgress)

        // Wait a bit to have a duration
        try? await Task.sleep(nanoseconds: 100_000_000)

        await viewModel.endWorkout()

        #expect(!viewModel.isWorkoutInProgress)
        #expect(viewModel.currentWorkout == nil)
        #expect(mockHealthKit.saveWorkoutCallCount == 1)
    }

    @Test("Should handle end workout error")
    func testEndWorkoutError() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()
        mockHealthKit.shouldFail = true
        mockHealthKit.errorToThrow = .saveFailed(NSError(domain: "test", code: -1))

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        viewModel.startWorkout(type: .running)
        await viewModel.endWorkout()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Failed to save workout") == true)
    }

    @Test("Should handle end workout when no workout in progress")
    func testEndWorkoutWithNoWorkout() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        await viewModel.endWorkout()

        #expect(viewModel.errorMessage == "No workout in progress")
    }

    @Test("Should delete workout")
    func testDeleteWorkout() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let workout = WorkoutData(
            activityType: .running,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600)
        )
        mockHealthKit.addMockWorkout(workout)

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        await viewModel.loadWorkouts()
        #expect(viewModel.workouts.count == 1)

        await viewModel.deleteWorkout(workout)

        #expect(mockHealthKit.deleteWorkoutCallCount == 1)
        #expect(mockHealthKit.fetchWorkoutsCallCount >= 2) // Once for load, once for refresh after delete
    }

    // MARK: - Statistics Tests

    @Test("Should load statistics")
    func testLoadStatistics() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let sample1 = HealthSample(value: 70.0, unit: "bpm", startDate: Date())
        let sample2 = HealthSample(value: 80.0, unit: "bpm", startDate: Date())
        mockHealthKit.addMockHeartRateSample(sample1)
        mockHealthKit.addMockHeartRateSample(sample2)

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        await viewModel.loadStatistics()

        #expect(viewModel.averageHeartRate == 75.0)
        #expect(!viewModel.isLoading)
    }

    @Test("Should refresh all data")
    func testRefresh() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let workout = WorkoutData(
            activityType: .running,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            totalEnergyBurned: 300
        )
        mockHealthKit.addMockWorkout(workout)

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        await viewModel.refresh()

        #expect(viewModel.workouts.count == 1)
        #expect(mockHealthKit.fetchWorkoutsCallCount >= 1)
    }

    // MARK: - Formatting Tests

    @Test("Should format duration correctly")
    func testFormattedDuration() {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        #expect(viewModel.formattedDuration(3661) == "01:01:01") // 1 hour, 1 minute, 1 second
        #expect(viewModel.formattedDuration(90) == "01:30") // 1 minute, 30 seconds
        #expect(viewModel.formattedDuration(45) == "00:45") // 45 seconds
    }

    @Test("Should format calories correctly")
    func testFormattedCalories() {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        #expect(viewModel.formattedCalories(300.5) == "300 kcal")
        #expect(viewModel.formattedCalories(nil) == "N/A")
    }

    // MARK: - Integration Tests

    @Test("Should handle complete workout flow")
    func testCompleteWorkoutFlow() async {
        let mockNetwork = MockNetworkService()
        let mockHealthKit = MockHealthKitService()

        let viewModel = WorkoutViewModel(
            networkService: mockNetwork,
            healthKitService: mockHealthKit
        )

        // 1. Request authorization
        await viewModel.requestHealthKitAuthorization()
        #expect(viewModel.isHealthKitAuthorized)

        // 2. Start workout
        viewModel.startWorkout(type: .running)
        #expect(viewModel.isWorkoutInProgress)

        // 3. End workout
        try? await Task.sleep(nanoseconds: 100_000_000)
        await viewModel.endWorkout()
        #expect(!viewModel.isWorkoutInProgress)
        #expect(mockHealthKit.saveWorkoutCallCount == 1)

        // 4. Load workouts
        await viewModel.loadWorkouts()
        #expect(viewModel.workouts.count == 1)
    }
}
