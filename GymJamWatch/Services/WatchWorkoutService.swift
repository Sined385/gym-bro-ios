//
//  WatchWorkoutService.swift
//  GymJamWatch
//
//  Manages HKWorkoutSession + HKLiveWorkoutBuilder for background HR tracking.
//

import Foundation
import HealthKit
import Combine

@MainActor
final class WatchWorkoutService: NSObject, ObservableObject {

    // MARK: - Published

    @Published var currentHeartRate: Double = 0
    @Published var averageHeartRate: Double = 0
    @Published var maxHeartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var isWorkoutActive = false
    @Published var workoutStartFailed = false

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateSamples: [WatchHeartRateSample] = []
    private var pendingBatchSamples: [WatchHeartRateSample] = []
    private var batchTimer: Timer?

    var onHeartRateBatchReady: ((WatchHeartRateBatch) -> Void)?
    /// Fires once per successful HKWorkoutSession start. The session VM
    /// forwards it to the phone so it knows the Watch owns the HealthKit
    /// workout (and skips its own duplicate save at completion).
    var onWorkoutStarted: (() -> Void)?

    // MARK: - Authorization

    func requestAuthorization() async {
        let typesToShare: Set<HKSampleType> = [
            .workoutType()
        ]

        var typesToRead: Set<HKObjectType> = [
            .workoutType()
        ]
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            typesToRead.insert(hr)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            typesToRead.insert(energy)
        }

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        } catch {
            print("⌚ HealthKit auth failed: \(error)")
            workoutStartFailed = true
            WatchHaptics.error()
        }
    }

    // MARK: - Workout Session

    func startWorkout() async {
        // Idempotent: the session can be started from two paths — the
        // phone's HKHealthStore.startWatchApp launch handoff AND the
        // WCSession state push binding. Whichever lands first wins; the
        // second call must not spin up a competing HKWorkoutSession.
        guard workoutSession == nil else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()

            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            session.delegate = self
            builder.delegate = self

            self.workoutSession = session
            self.workoutBuilder = builder

            session.startActivity(with: Date())
            try await builder.beginCollection(at: Date())

            isWorkoutActive = true
            workoutStartFailed = false
            startBatchTimer()

            WatchHaptics.workoutStarted()
            onWorkoutStarted?()
        } catch {
            print("⌚ Failed to start workout: \(error)")
            workoutStartFailed = true
            WatchHaptics.error()
        }
    }

    func endWorkout() async -> WatchWorkoutSummary? {
        guard let session = workoutSession, let builder = workoutBuilder else { return nil }

        session.end()

        do {
            try await builder.endCollection(at: Date())
            try await builder.finishWorkout()
        } catch {
            print("⌚ Failed to finish workout: \(error)")
        }

        stopBatchTimer()
        flushPendingBatch()

        isWorkoutActive = false

        let summary = WatchWorkoutSummary(
            totalDurationSeconds: Int(builder.elapsedTime),
            activeCalories: activeCalories,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil
        )

        // Reset
        workoutSession = nil
        workoutBuilder = nil
        heartRateSamples.removeAll()
        pendingBatchSamples.removeAll()
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        activeCalories = 0

        WatchHaptics.workoutCompleted()

        return summary
    }

    // MARK: - Batch Timer

    private func startBatchTimer() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flushPendingBatch()
            }
        }
    }

    private func stopBatchTimer() {
        batchTimer?.invalidate()
        batchTimer = nil
    }

    private func flushPendingBatch() {
        guard !pendingBatchSamples.isEmpty else { return }
        let batch = WatchHeartRateBatch(samples: pendingBatchSamples)
        pendingBatchSamples.removeAll()
        onHeartRateBatchReady?(batch)
    }

    // MARK: - HR Processing

    private func processHeartRateSample(bpm: Double, date: Date) {
        currentHeartRate = bpm
        if bpm > maxHeartRate { maxHeartRate = bpm }

        let sample = WatchHeartRateSample(bpm: bpm, timestamp: date)
        heartRateSamples.append(sample)
        pendingBatchSamples.append(sample)

        // Recalculate average
        let total = heartRateSamples.reduce(0.0) { $0 + $1.bpm }
        averageHeartRate = total / Double(heartRateSamples.count)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutService: @preconcurrency HKWorkoutSessionDelegate {

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            self.isWorkoutActive = (toState == .running)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("⌚ Workout session failed: \(error)")
        Task { @MainActor in
            WatchHaptics.error()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutService: @preconcurrency HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                let bpmUnit = HKUnit.count().unitDivided(by: .minute())

                if let mostRecent = statistics?.mostRecentQuantity()?.doubleValue(for: bpmUnit) {
                    Task { @MainActor in
                        self.processHeartRateSample(bpm: mostRecent, date: Date())
                    }
                }
            }

            if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let total = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    Task { @MainActor in
                        self.activeCalories = total
                    }
                }
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Not used for strength training
    }
}
