//
//  WatchSessionViewModel.swift
//  GymJamWatch
//
//  Mirrors session state from iPhone and manages workout lifecycle.
//

import Foundation
import Combine

@MainActor
final class WatchSessionViewModel: ObservableObject {

    // MARK: - Published

    @Published var sessionState: WatchSessionState?
    @Published var isSessionActive = false
    @Published var showSummary = false
    @Published var workoutSummary: WatchWorkoutSummary?
    @Published var currentHeartRate: Double = 0
    @Published var averageHeartRate: Double = 0
    @Published var maxHeartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var elapsedSeconds: Int = 0
    @Published var lastCompletedWeight: Double?
    @Published var lastCompletedReps: Int?

    // MARK: - Computed

    var sessionTitle: String {
        sessionState?.sessionTitle ?? "Workout"
    }

    var elapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var currentExercise: WatchExerciseState? {
        sessionState?.currentExercise
    }

    var exercises: [WatchExerciseState] {
        sessionState?.exercises ?? []
    }

    var totalSetsCompleted: Int {
        sessionState?.totalSetsCompleted ?? 0
    }

    var totalSets: Int {
        sessionState?.totalSets ?? 0
    }

    var isResting: Bool {
        sessionState?.isResting ?? false
    }

    // MARK: - Dependencies

    private let connectivityService: PhoneConnectivityService
    private let workoutService: WatchWorkoutService
    private var cancellables = Set<AnyCancellable>()
    private var elapsedTimerCancellable: AnyCancellable?

    // MARK: - Init

    init(connectivityService: PhoneConnectivityService, workoutService: WatchWorkoutService) {
        self.connectivityService = connectivityService
        self.workoutService = workoutService
        setupBindings()
    }

    private func setupBindings() {
        // Mirror session state from connectivity
        connectivityService.$sessionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.sessionState = state
                let wasActive = self.isSessionActive
                let isNowActive = state != nil
                self.isSessionActive = isNowActive

                // Re-anchor elapsed time from sessionStartDate on each state update
                if let startDate = state?.sessionStartDate {
                    self.elapsedSeconds = max(0, Int(Date().timeIntervalSince(startDate)))
                }

                // Derive last completed set from state for repeat feature
                if let exercises = state?.exercises {
                    let allCompleted = exercises.flatMap { $0.sets }.filter(\.isCompleted)
                    if let last = allCompleted.last, (last.weight != nil || last.reps != nil) {
                        self.lastCompletedWeight = last.weight
                        self.lastCompletedReps = last.reps
                    }
                }

                // Auto-start HK workout + local timer when session begins
                if !wasActive && isNowActive {
                    self.startElapsedTimer()
                    Task { [weak self] in
                        await self?.workoutService.requestAuthorization()
                        await self?.workoutService.startWorkout()
                    }
                }

                // Stop timer when session ends
                if wasActive && !isNowActive {
                    self.stopElapsedTimer()
                }
            }
            .store(in: &cancellables)

        // Heart rate from workout service
        workoutService.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentHeartRate)

        workoutService.$averageHeartRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$averageHeartRate)

        workoutService.$maxHeartRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$maxHeartRate)

        workoutService.$activeCalories
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeCalories)

        // Track last completed set for repeat feature
        connectivityService.onSetCompletionConfirmed = { [weak self] (_: String, _: String, weight: Double?, reps: Int) in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastCompletedWeight = weight
                self.lastCompletedReps = reps
            }
        }

        // Forward HR batches to phone
        workoutService.onHeartRateBatchReady = { [weak self] batch in
            self?.connectivityService.sendHeartRateBatch(batch)
        }

        // Tell the phone the Watch owns the HealthKit workout so it
        // doesn't write a duplicate HKWorkout at completion.
        workoutService.onWorkoutStarted = { [weak self] in
            self?.connectivityService.sendWorkoutStarted()
        }

        // Handle session ended from phone. `completed` distinguishes a real
        // finish from a discard: always end the HealthKit workout (releases the
        // session + sends the summary the phone may use for calories/HR), but
        // only surface the summary UI when the workout was actually completed.
        // A discard clears silently — no "completed" summary flash.
        connectivityService.onSessionEnded = { [weak self] completed in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let summary = await self.workoutService.endWorkout()
                if completed {
                    // Show the summary. `sessionEnded` fires twice per end
                    // (VM + teardown); the 2nd endWorkout() returns nil, so
                    // only set when we actually have a summary — never clear a
                    // summary already shown by the 1st call.
                    if let summary {
                        self.workoutSummary = summary
                        self.connectivityService.sendWorkoutSummary(summary)
                        self.showSummary = true
                    }
                } else {
                    // Discard → clear silently, no summary.
                    self.workoutSummary = nil
                    self.showSummary = false
                }
                self.isSessionActive = false
            }
        }
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        elapsedTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let startDate = self.sessionState?.sessionStartDate else { return }
                self.elapsedSeconds = max(0, Int(Date().timeIntervalSince(startDate)))
            }
    }

    private func stopElapsedTimer() {
        elapsedTimerCancellable?.cancel()
        elapsedTimerCancellable = nil
        elapsedSeconds = 0
    }

    // MARK: - Actions

    func dismissSummary() {
        showSummary = false
        workoutSummary = nil
        stopElapsedTimer()
    }
}
