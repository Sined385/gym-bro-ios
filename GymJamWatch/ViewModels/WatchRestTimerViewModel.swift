//
//  WatchRestTimerViewModel.swift
//  GymJamWatch
//
//  Countdown + haptics for rest timer on Watch.
//

import Foundation
import Combine

@MainActor
final class WatchRestTimerViewModel: ObservableObject {

    // MARK: - Published

    @Published var remaining: Int = 0
    @Published var totalDuration: Int = 0
    @Published var isActive = false
    @Published var isFinished = false

    // MARK: - Computed

    var formattedTime: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(totalDuration - remaining) / Double(totalDuration)
    }

    // MARK: - Dependencies

    private let connectivityService: PhoneConnectivityService
    private var localTimer: Timer?
    private var restStartDate: Date?
    private var restDurationSeconds: Int = 0
    private var lastHaptic30s: Int = 0
    /// Best-known rest duration for optimistic starts — updated from every
    /// real (phone-anchored) timer start so mid-session it matches the
    /// user's configured rest time. 90s only before the first real rest.
    private var lastKnownRestDuration = 90
    /// Set when the countdown was started optimistically (set completed on
    /// the Watch, phone push not yet arrived). Shields the timer from the
    /// phone's set-completion state push, which is sent BEFORE its rest
    /// timer starts and still says isResting=false.
    private var optimisticStartDate: Date?

    // MARK: - Init

    init(connectivityService: PhoneConnectivityService) {
        self.connectivityService = connectivityService
        setupBindings()
    }

    private func setupBindings() {
        // Receive timer ticks from phone
        connectivityService.onRestTimerTick = { [weak self] remaining in
            Task { @MainActor [weak self] in
                self?.updateRemaining(remaining)
            }
        }

        // Watch for session state changes to sync rest timer
        connectivityService.$sessionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                if let state, state.isResting, let restRemaining = state.restTimeRemaining {
                    // Authoritative phone state — re-anchor (also corrects
                    // an optimistic start's guessed duration).
                    self.optimisticStartDate = nil
                    self.startLocalTimer(
                        remaining: restRemaining,
                        restStartDate: state.restStartDate,
                        totalDuration: state.restDurationSeconds
                    )
                } else if state?.isResting == false {
                    // Ignore isResting=false pushes right after an
                    // optimistic start: the phone sends its set-completion
                    // state before starting its own rest timer.
                    if let optimistic = self.optimisticStartDate,
                       Date().timeIntervalSince(optimistic) < 5 { return }
                    self.stopTimer()
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Local Timer (fallback when phone unreachable)

    /// Start counting immediately after a set is completed ON the Watch,
    /// without waiting for the phone's rest-state push (a reachability
    /// round-trip away — the user otherwise lingers on the sets screen).
    /// Flipping isActive here is what auto-pages ActiveWorkoutView to the
    /// timer. The phone's authoritative push re-anchors moments later.
    func startOptimistically() {
        guard !isActive else { return }
        optimisticStartDate = Date()
        startLocalTimer(
            remaining: lastKnownRestDuration,
            restStartDate: Date(),
            totalDuration: lastKnownRestDuration
        )
    }

    func startLocalTimer(remaining: Int, restStartDate: Date?, totalDuration: Int) {
        if totalDuration > 0 { lastKnownRestDuration = totalDuration }
        self.remaining = remaining
        self.totalDuration = totalDuration
        self.restStartDate = restStartDate
        self.restDurationSeconds = totalDuration
        self.isActive = true
        self.lastHaptic30s = (remaining / 30) * 30

        localTimer?.invalidate()
        localTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickLocal()
            }
        }
    }

    private func tickLocal() {
        // Recalculate from anchor if available
        if let start = restStartDate {
            let elapsed = Int(Date().timeIntervalSince(start))
            remaining = max(0, restDurationSeconds - elapsed)
        } else {
            remaining = max(0, remaining - 1)
        }

        // 30s haptic warning
        let current30s = (remaining / 30) * 30
        if current30s < lastHaptic30s && remaining > 0 {
            WatchHaptics.restTimer30sWarning()
            lastHaptic30s = current30s
        }

        if remaining <= 0 {
            timerFinished()
        }
    }

    private func updateRemaining(_ value: Int) {
        remaining = value
        if !isActive && value > 0 {
            isActive = true
            totalDuration = max(totalDuration, value)
        }
        if value <= 0 {
            timerFinished()
        }
    }

    private func timerFinished() {
        localTimer?.invalidate()
        localTimer = nil
        remaining = 0
        restStartDate = nil
        isFinished = true
        WatchHaptics.restTimerFinished()

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.isFinished = false
            self?.isActive = false
        }
    }

    func stopTimer() {
        localTimer?.invalidate()
        localTimer = nil
        isActive = false
        isFinished = false
        remaining = 0
        restStartDate = nil
        optimisticStartDate = nil
    }

    // MARK: - Actions

    func skip() {
        stopTimer()
        connectivityService.sendRestTimerAction(.skip)
    }

    func extend30() {
        restDurationSeconds += 30
        totalDuration += 30
        remaining += 30
        connectivityService.sendRestTimerAction(.extend30)
    }
}
