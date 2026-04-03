//
//  ActiveSessionManager.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import UIKit
import Combine
import SwiftUI
import UserNotifications
import FirebaseAnalytics

@MainActor
final class ActiveSessionManager: ObservableObject {

    // MARK: - Presentation State

    enum PresentationState: Equatable {
        case hidden
        case expanded
        case collapsed
    }

    // MARK: - Published Properties

    @Published var presentationState: PresentationState = .hidden
    @Published var sessionId: String?
    @Published var sessionTitle: String?
    @Published var sessionExercises: [DashboardExercise] = []
    @Published var elapsedSeconds: Int = 0
    @Published var restTimeRemaining: Int?
    @Published var isWorkoutStarted: Bool = false

    // MARK: - Restored Session Data

    var restoredExercises: [ActiveSessionExercise]?
    var restoredFeedback: (effort: Int, energy: Int, pain: String)?

    // MARK: - Timer

    private var timerCancellable: AnyCancellable?
    private var restTimerCancellable: AnyCancellable?
    private static let restNotificationId = "gym-bro-rest-complete"
    private static let stillThereNotificationId = "gym-bro-still-there"
    private static let stillThereDelaySeconds: TimeInterval = 600 // 10 minutes

    // MARK: - Date-Anchored Timer State

    private var sessionStartDate: Date?
    private var restStartDate: Date?
    private var restDurationSeconds: Int = 0
    private var foregroundCancellable: AnyCancellable?
    private var backgroundCancellable: AnyCancellable?

    // MARK: - Reload Trigger

    private let appDataState: AppDataState

    // MARK: - Persistence

    private static let cacheKey = "gym-bro-active-session-cache"
    private var lastSavedExercises: [ActiveSessionExercise]?
    private var lastSavedFeedback: (effort: Int, energy: Int, pain: String)?

    // MARK: - Computed Properties

    var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var isResting: Bool { restTimeRemaining != nil }

    var formattedRestTime: String {
        guard let remaining = restTimeRemaining else { return "" }
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var isSessionActive: Bool { presentationState != .hidden }
    var isExpanded: Bool { presentationState == .expanded }
    var isCollapsed: Bool { presentationState == .collapsed }

    // MARK: - Init

    init(appDataState: AppDataState) {
        self.appDataState = appDataState
        foregroundCancellable = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recalculateElapsedTime()
                    self?.recalculateRestTime()
                }
            }

        backgroundCancellable = NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isSessionActive else { return }
                    self.saveSession(
                        exercises: self.lastSavedExercises ?? [],
                        effortLevel: self.lastSavedFeedback?.effort ?? 5,
                        energyLevel: self.lastSavedFeedback?.energy ?? 3,
                        painDiscomfort: self.lastSavedFeedback?.pain ?? "None"
                    )
                }
            }
    }

    // MARK: - Session Lifecycle

    func openSession(_ session: SessionResponse) {
        sessionId = session.id
        sessionTitle = session.title
        sessionExercises = session.exercises
        elapsedSeconds = 0
        isWorkoutStarted = false
        sessionStartDate = nil
        presentationState = .expanded

        Analytics.logEvent("workout_opened", parameters: [
            "session_type": session.type,
            "is_ai_generated": (session.aiGenerated ?? false) ? "true" : "false"
        ])
    }

    func beginWorkout() {
        isWorkoutStarted = true
        sessionStartDate = Date()
        startTimer()
        scheduleStillThereNotification()

        Analytics.logEvent("workout_started", parameters: [:])
    }

    func refreshInactivityTimer() {
        cancelStillThereNotification()
        scheduleStillThereNotification()
    }

    func expand() {
        presentationState = .expanded
    }

    func collapse() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        presentationState = .collapsed
    }

    func endSession() {
        stopTimer()
        skipRestTimer()
        cancelStillThereNotification()
        presentationState = .hidden
        sessionId = nil
        sessionTitle = nil
        sessionExercises = []
        sessionStartDate = nil
        isWorkoutStarted = false
        lastSavedExercises = nil
        lastSavedFeedback = nil
        restoredExercises = nil
        restoredFeedback = nil
        clearCache()
        appDataState.triggerReload()
    }

    // MARK: - Timer

    private func recalculateElapsedTime() {
        guard let start = sessionStartDate else { return }
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(start)))
    }

    func startTimer() {
        if sessionStartDate == nil {
            sessionStartDate = Date()
        }
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recalculateElapsedTime()
                }
            }
    }

    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Rest Timer

    private func recalculateRestTime() {
        guard let start = restStartDate else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let remaining = restDurationSeconds - elapsed
        if remaining > 0 {
            restTimeRemaining = remaining
        } else {
            restTimerCancellable?.cancel()
            restTimerCancellable = nil
            restStartDate = nil
            restDurationSeconds = 0
            restTimeRemaining = nil
        }
    }

    func startRestTimer(seconds: Int? = nil) {
        let seconds = seconds ?? {
            let stored = UserDefaults.standard.integer(forKey: SettingsViewModel.restTimeKey)
            return stored > 0 ? stored : 90
        }()
        restTimerCancellable?.cancel()
        restStartDate = Date()
        restDurationSeconds = seconds
        restTimeRemaining = seconds
        scheduleRestNotification(seconds: seconds)
        scheduleStillThereNotification()

        restTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recalculateRestTime()
                }
            }
    }

    func addRestTime(_ seconds: Int) {
        restDurationSeconds += seconds
        recalculateRestTime()
        if let remaining = restTimeRemaining, remaining > 0 {
            scheduleRestNotification(seconds: remaining)
        }
    }

    func skipRestTimer() {
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        restStartDate = nil
        restDurationSeconds = 0
        restTimeRemaining = nil
        cancelRestNotification()
        cancelStillThereNotification()
    }

    // MARK: - Rest Notification

    private func scheduleRestNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()
        cancelRestNotification()

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Rest Complete"
            content.body = "Time to start your next set!"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
            let request = UNNotificationRequest(identifier: Self.restNotificationId, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.restNotificationId])
    }

    // MARK: - "Still There?" Notification

    /// Schedules a local notification after a set is completed.
    /// Cancelled automatically when a new set is logged or session ends.
    private func scheduleStillThereNotification() {
        let center = UNUserNotificationCenter.current()
        cancelStillThereNotification()

        let content = UNMutableNotificationContent()
        content.title = "Still there?"
        content.body = "Your workout is waiting — get back to it!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.stillThereDelaySeconds,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.stillThereNotificationId,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelStillThereNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.stillThereNotificationId]
        )
    }

    // MARK: - Session Persistence

    struct CachedSession: Codable {
        let sessionId: String
        let sessionTitle: String
        let sessionStartDate: Date?
        let exercises: [ActiveSessionExercise]
        let sessionExercises: [DashboardExercise]
        let presentationState: String
        let effortLevel: Int
        let energyLevel: Int
        let painDiscomfort: String
        let restStartDate: Date?
        let restDurationSeconds: Int
        let isWorkoutStarted: Bool
    }

    func saveSession(exercises: [ActiveSessionExercise], effortLevel: Int, energyLevel: Int, painDiscomfort: String) {
        guard let sessionId, let sessionTitle else { return }

        lastSavedExercises = exercises
        lastSavedFeedback = (effortLevel, energyLevel, painDiscomfort)

        let stateString: String
        switch presentationState {
        case .hidden: stateString = "hidden"
        case .expanded: stateString = "expanded"
        case .collapsed: stateString = "collapsed"
        }

        let cached = CachedSession(
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            sessionStartDate: sessionStartDate,
            exercises: exercises,
            sessionExercises: sessionExercises,
            presentationState: stateString,
            effortLevel: effortLevel,
            energyLevel: energyLevel,
            painDiscomfort: painDiscomfort,
            restStartDate: restStartDate,
            restDurationSeconds: restDurationSeconds,
            isWorkoutStarted: isWorkoutStarted
        )

        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }

    func restoreSessionIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let cached = try? JSONDecoder().decode(CachedSession.self, from: data) else { return }

        sessionId = cached.sessionId
        sessionTitle = cached.sessionTitle
        sessionStartDate = cached.sessionStartDate
        sessionExercises = cached.sessionExercises
        isWorkoutStarted = cached.isWorkoutStarted

        switch cached.presentationState {
        case "expanded": presentationState = .expanded
        case "collapsed": presentationState = .collapsed
        default: presentationState = .expanded
        }

        if isWorkoutStarted {
            recalculateElapsedTime()
            startTimer()
        }

        // Restore rest timer only if still within time window
        if let restStart = cached.restStartDate {
            let elapsed = Int(Date().timeIntervalSince(restStart))
            let remaining = cached.restDurationSeconds - elapsed
            if remaining > 0 {
                restStartDate = restStart
                restDurationSeconds = cached.restDurationSeconds
                restTimeRemaining = remaining

                restTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        Task { @MainActor [weak self] in
                            self?.recalculateRestTime()
                        }
                    }
            }
        }

        restoredExercises = cached.exercises
        // Only restore feedback if user actually selected values
        if cached.effortLevel > 0 || cached.energyLevel > 0 || !cached.painDiscomfort.isEmpty {
            restoredFeedback = (cached.effortLevel, cached.energyLevel, cached.painDiscomfort)
        }
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: Self.cacheKey)
    }
}
