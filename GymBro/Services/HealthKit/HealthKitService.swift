//
//  HealthKitService.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import HealthKit

/// Production implementation of HealthKitServiceProtocol
final class HealthKitService: HealthKitServiceProtocol {

    // MARK: - Properties

    private let healthStore: HKHealthStore

    // Define the health data types we need
    private let typesToRead: Set<HKObjectType> = {
        var types = Set<HKObjectType>()

        // Workouts
        types.insert(HKObjectType.workoutType())

        // Heart Rate
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }

        // Active Energy
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        // Body Measurements
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        if let leanMass = HKObjectType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(leanMass)
        }
        if let height = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let bioSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(bioSex)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let vo2 = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        return types
    }()

    private let typesToWrite: Set<HKSampleType> = {
        var types = Set<HKSampleType>()

        // Workouts
        types.insert(HKObjectType.workoutType())

        // Heart Rate
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }

        // Active Energy
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        // Body Measurements
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        if let leanMass = HKObjectType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(leanMass)
        }

        return types
    }()

    // MARK: - Initialization

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    // MARK: - Authorization

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }

    // MARK: - Workouts

    func startWatchWorkoutApp() async {
        guard isHealthDataAvailable else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        do {
            try await healthStore.startWatchApp(toHandle: configuration)
        } catch {
            // No paired Watch / Watch app not installed — nothing to do.
            print("startWatchApp skipped: \(error.localizedDescription)")
        }
    }

    func saveWorkout(_ workout: WorkoutData) async throws {
        let energyBurned = workout.totalEnergyBurned.map {
            HKQuantity(unit: .kilocalorie(), doubleValue: $0)
        }

        let distance = workout.totalDistance.map {
            HKQuantity(unit: .meter(), doubleValue: $0)
        }

        let hkWorkout = HKWorkout(
            activityType: workout.activityType,
            start: workout.startDate,
            end: workout.endDate,
            duration: workout.duration,
            totalEnergyBurned: energyBurned,
            totalDistance: distance,
            metadata: workout.metadata
        )

        do {
            try await healthStore.save(hkWorkout)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let workoutData = workouts.map { workout in
                    WorkoutData(
                        id: workout.uuid,
                        activityType: workout.workoutActivityType,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        duration: workout.duration,
                        totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                        totalDistance: workout.totalDistance?.doubleValue(for: .meter()),
                        metadata: workout.metadata
                    )
                }

                continuation.resume(returning: workoutData)
            }

            healthStore.execute(query)
        }
    }

    func deleteWorkout(workoutId: UUID) async throws {
        let predicate = HKQuery.predicateForObject(with: workoutId)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { [weak self] _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(throwing: HealthKitError.noData)
                    return
                }

                Task {
                    do {
                        try await self?.healthStore.delete(workout)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: HealthKitError.deleteFailed(error))
                    }
                }
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Heart Rate

    func fetchHeartRate(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidData
        }

        return try await fetchQuantitySamples(
            type: heartRateType,
            unit: .count().unitDivided(by: .minute()),
            startDate: startDate,
            endDate: endDate
        )
    }

    func saveHeartRate(_ heartRate: Double, date: Date) async throws {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidData
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let quantity = HKQuantity(unit: unit, doubleValue: heartRate)

        try await saveQuantitySample(
            type: heartRateType,
            quantity: quantity,
            startDate: date,
            endDate: date
        )
    }

    func fetchAverageHeartRate(from startDate: Date, to endDate: Date) async throws -> Double? {
        let samples = try await fetchHeartRate(from: startDate, to: endDate)
        guard !samples.isEmpty else { return nil }

        let total = samples.reduce(0.0) { $0 + $1.value }
        return total / Double(samples.count)
    }

    func fetchRestingHeartRate() async throws -> Double? {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Active Energy

    func fetchActiveEnergy(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.invalidData
        }

        return try await fetchQuantitySamples(
            type: activeEnergyType,
            unit: .kilocalorie(),
            startDate: startDate,
            endDate: endDate
        )
    }

    func saveActiveEnergy(_ energy: Double, from startDate: Date, to endDate: Date) async throws {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.invalidData
        }

        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: energy)

        try await saveQuantitySample(
            type: activeEnergyType,
            quantity: quantity,
            startDate: startDate,
            endDate: endDate
        )
    }

    func fetchTotalActiveEnergy(from startDate: Date, to endDate: Date) async throws -> Double {
        let samples = try await fetchActiveEnergy(from: startDate, to: endDate)
        return samples.reduce(0.0) { $0 + $1.value }
    }

    // MARK: - Body Measurements

    func saveWeight(_ weight: Double, date: Date) async throws {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.invalidData
        }

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weight)

        try await saveQuantitySample(
            type: weightType,
            quantity: quantity,
            startDate: date,
            endDate: date
        )
    }

    func fetchWeight(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.invalidData
        }

        return try await fetchQuantitySamples(
            type: weightType,
            unit: .gramUnit(with: .kilo),
            startDate: startDate,
            endDate: endDate
        )
    }

    func fetchLatestWeight() async throws -> HealthSample? {
        let samples = try await fetchWeight(
            from: Date.distantPast,
            to: Date()
        )
        return samples.first
    }

    func fetchLatestHeight() async throws -> HealthSample? {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else {
            throw HealthKitError.invalidData
        }

        let samples = try await fetchQuantitySamples(
            type: heightType,
            unit: .meterUnit(with: .centi),
            startDate: Date.distantPast,
            endDate: Date()
        )
        return samples.first
    }

    func fetchBiologicalSex() -> HKBiologicalSex? {
        guard isHealthDataAvailable else { return nil }
        return try? healthStore.biologicalSex().biologicalSex
    }

    func saveBodyFatPercentage(_ bodyFat: Double, date: Date) async throws {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            throw HealthKitError.invalidData
        }

        let quantity = HKQuantity(unit: .percent(), doubleValue: bodyFat / 100.0)

        try await saveQuantitySample(
            type: bodyFatType,
            quantity: quantity,
            startDate: date,
            endDate: date
        )
    }

    func fetchBodyFatPercentage(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            throw HealthKitError.invalidData
        }

        return try await fetchQuantitySamples(
            type: bodyFatType,
            unit: .percent(),
            startDate: startDate,
            endDate: endDate
        ).map { sample in
            // Convert back to percentage (0-100)
            HealthSample(
                id: sample.id,
                value: sample.value * 100,
                unit: "%",
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        }
    }

    func saveLeanBodyMass(_ leanMass: Double, date: Date) async throws {
        guard let leanMassType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) else {
            throw HealthKitError.invalidData
        }

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: leanMass)

        try await saveQuantitySample(
            type: leanMassType,
            quantity: quantity,
            startDate: date,
            endDate: date
        )
    }

    func fetchLeanBodyMass(from startDate: Date, to endDate: Date) async throws -> [HealthSample] {
        guard let leanMassType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) else {
            throw HealthKitError.invalidData
        }

        return try await fetchQuantitySamples(
            type: leanMassType,
            unit: .gramUnit(with: .kilo),
            startDate: startDate,
            endDate: endDate
        )
    }

    // MARK: - Dashboard Stats

    func fetchLatestBodyFat() async throws -> Double? {
        let samples = try await fetchBodyFatPercentage(from: Date.distantPast, to: Date())
        return samples.first?.value
    }

    func fetchLatestLeanBodyMass() async throws -> Double? {
        let samples = try await fetchLeanBodyMass(from: Date.distantPast, to: Date())
        return samples.first?.value
    }

    func fetchTodayStepCount() async throws -> Double? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let samples = try await fetchQuantitySamples(type: stepType, unit: .count(), startDate: start, endDate: end)
        let total = samples.reduce(0.0) { $0 + $1.value }
        return total > 0 ? total : nil
    }

    func fetchLastNightSleepDuration() async throws -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        // Look at samples from yesterday 6pm to today noon
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let queryStart = cal.date(byAdding: .hour, value: -30, to: todayStart) ?? todayStart
        let queryEnd = cal.date(byAdding: .hour, value: 12, to: todayStart) ?? now

        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: [.strictStartDate])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Sum asleep durations (inBed=0, asleepUnspecified=1, asleepCore/Deep/REM=3,4,5)
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]

                var totalSeconds: TimeInterval = 0
                for sample in categorySamples {
                    if asleepValues.contains(sample.value) {
                        totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }

                let hours = totalSeconds / 3600
                continuation.resume(returning: hours > 0 ? hours : nil)
            }

            healthStore.execute(query)
        }
    }

    func fetchLatestHRV() async throws -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let ms = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: ms)
            }

            healthStore.execute(query)
        }
    }

    func fetchLatestVO2Max() async throws -> Double? {
        guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return nil }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                // mL/(kg·min)
                let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    func fetchTodayWalkingDistance() async throws -> Double? {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let samples = try await fetchQuantitySamples(type: distanceType, unit: .meterUnit(with: .kilo), startDate: start, endDate: end)
        let total = samples.reduce(0.0) { $0 + $1.value }
        return total > 0 ? total : nil
    }

    // MARK: - Private Helpers

    private func fetchQuantitySamples(
        type: HKQuantityType,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthSample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let healthSamples = quantitySamples.map { sample in
                    HealthSample(
                        id: sample.uuid,
                        value: sample.quantity.doubleValue(for: unit),
                        unit: unit.unitString,
                        startDate: sample.startDate,
                        endDate: sample.endDate
                    )
                }

                continuation.resume(returning: healthSamples)
            }

            healthStore.execute(query)
        }
    }

    private func saveQuantitySample(
        type: HKQuantityType,
        quantity: HKQuantity,
        startDate: Date,
        endDate: Date
    ) async throws {
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: startDate,
            end: endDate
        )

        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }
}
