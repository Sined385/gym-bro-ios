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
    @Published var showSessionConflict = false
    private var pendingSessionStart: (@MainActor () async -> Void)?

    // MARK: - Restored Session Data

    var restoredExercises: [ActiveSessionExercise]?
    var restoredFeedback: (effort: Int, energy: Int, pain: String)?

    // MARK: - Timer

    private var timerCancellable: AnyCancellable?
    private var restTimerCancellable: AnyCancellable?
    private static let restNotificationId = "gym-bro-rest-complete"
    private static let stillThereNotificationId = "gym-bro-still-there"
    private static let stillThereDelaySeconds: TimeInterval = 600 // 10 minutes
    private static let startReminderIdPrefix = "gym-bro-start-reminder-"

    private static func startReminderId(for sessionId: String) -> String {
        "\(startReminderIdPrefix)\(sessionId)"
    }

    /// Tracks which session we've already fired the start-reminder for so
    /// the second/third/... exercise added doesn't fire it again.
    private var startReminderFiredForSessionId: String?

    // MARK: - Date-Anchored Timer State

    private var sessionStartDate: Date?
    private var restStartDate: Date?
    private var restDurationSeconds: Int = 0
    private var foregroundCancellable: AnyCancellable?
    private var backgroundCancellable: AnyCancellable?

    // MARK: - Live Activity

    private let liveActivityService: LiveActivityService
    private(set) var lastCompletedExerciseName: String?
    private(set) var lastCompletedSetDisplay: String?
    @Published var repeatLastSetRequested: Bool = false

    // MARK: - Watch Connectivity

    private let watchConnectivityService: WatchConnectivityServiceProtocol?
    @Published var watchWorkoutSummary: WatchWorkoutSummary?

    // MARK: - Reload Trigger

    private let appDataState: AppDataState
    private let analyticsService: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)

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

    var conflictSessionSummary: (title: String, formattedTime: String, exerciseCount: Int, completedSets: Int) {
        let count = lastSavedExercises?.count ?? sessionExercises.count
        let sets = lastSavedExercises?.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count } ?? 0
        return (sessionTitle ?? "Workout", formattedTime, count, sets)
    }

    // MARK: - Init

    init(appDataState: AppDataState, liveActivityService: LiveActivityService, watchConnectivityService: WatchConnectivityServiceProtocol? = nil) {
        self.appDataState = appDataState
        self.liveActivityService = liveActivityService
        self.watchConnectivityService = watchConnectivityService
        setupWatchCallbacks()
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

    func openSession(_ session: SessionResponse, autoStart: Bool = true) {
        print("🟡 openSession called: \(session.title), autoStart=\(autoStart), liveActivityService = \(liveActivityService)")
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

        if autoStart {
            beginWorkout(title: session.title, exerciseCount: session.exercises.count)
        }

        // Persist session metadata immediately so backgrounding before
        // SessionFlowViewModel's initial save doesn't lose the session
        saveSession(exercises: [], effortLevel: 0, energyLevel: 0, painDiscomfort: "")
    }

    /// Transition the currently-open session out of the pre-active "Add
    /// exercises / Start workout" state into a live workout (timer, live
    /// activity, still-there notification). Safe to call only once per session.
    func startWorkout() {
        guard !isWorkoutStarted, let title = sessionTitle else { return }
        beginWorkout(title: title, exerciseCount: sessionExercises.count)
        saveSession(
            exercises: lastSavedExercises ?? [],
            effortLevel: lastSavedFeedback?.effort ?? 0,
            energyLevel: lastSavedFeedback?.energy ?? 0,
            painDiscomfort: lastSavedFeedback?.pain ?? ""
        )
    }

    private func beginWorkout(title: String, exerciseCount: Int) {
        // Cancel the "ready to start?" nudge before flipping the started
        // flag — the cancel keys off sessionId which is still set here.
        cancelStartReminder()
        isWorkoutStarted = true
        sessionStartDate = Date()
        elapsedSeconds = 0
        startTimer()
        scheduleStillThereNotification()
        liveActivityService.startActivity(
            title: title,
            startDate: sessionStartDate!,
            exerciseCount: exerciseCount
        )
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
        analyticsService.track("session_collapsed", properties: [:])
    }

    func endSession() {
        let wasActive = isWorkoutStarted
        let exerciseCount = lastSavedExercises?.count ?? 0
        liveActivityService.endActivity()
        pushWatchSessionEnded()
        stopTimer()
        skipRestTimer()
        cancelStillThereNotification()
        cancelStartReminder()
        if wasActive {
            analyticsService.track("workout_cancelled", properties: ["exercise_count": exerciseCount])
        }
        presentationState = .hidden
        sessionId = nil
        sessionTitle = nil
        sessionExercises = []
        sessionStartDate = nil
        isWorkoutStarted = false
        lastSavedExercises = nil
        lastSavedFeedback = nil
        lastCompletedExerciseName = nil
        lastCompletedSetDisplay = nil
        repeatLastSetRequested = false
        restoredExercises = nil
        restoredFeedback = nil
        watchWorkoutSummary = nil
        watchHeartRateSamples.removeAll()
        clearCache()
        appDataState.triggerReload()
    }

    // MARK: - Session Conflict Gating

    func requestSessionStart(_ action: @escaping @MainActor () async -> Void) {
        if isSessionActive {
            pendingSessionStart = action
            showSessionConflict = true
        } else {
            Task { @MainActor in await action() }
        }
    }

    func confirmReplaceSession() {
        let pending = pendingSessionStart
        pendingSessionStart = nil
        showSessionConflict = false
        endSession()
        if let pending { Task { @MainActor in await pending() } }
    }

    func cancelReplaceSession() {
        pendingSessionStart = nil
        showSessionConflict = false
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
            pushRestTickToWatch()
        } else {
            restTimerCancellable?.cancel()
            restTimerCancellable = nil
            restStartDate = nil
            restDurationSeconds = 0
            restTimeRemaining = nil
            updateLiveActivity(isResting: false, restEndDate: nil)
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

        updateLiveActivity(isResting: true, restEndDate: currentRestEndDate)

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
        updateLiveActivity(isResting: false, restEndDate: nil)
    }

    // MARK: - Live Activity Helpers

    private var currentRestEndDate: Date? {
        guard let start = restStartDate else { return nil }
        return start.addingTimeInterval(TimeInterval(restDurationSeconds))
    }

    private func updateLiveActivity(isResting: Bool, restEndDate: Date?) {
        let state = WorkoutActivityAttributes.ContentState(
            isResting: isResting,
            restEndDate: restEndDate,
            lastExerciseName: lastCompletedExerciseName,
            lastSetDisplay: lastCompletedSetDisplay,
            totalSetsCompleted: lastSavedExercises?.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count } ?? 0,
            totalExercises: lastSavedExercises?.count ?? 0
        )
        liveActivityService.updateActivity(state: state)
    }

    func updateLastCompletedSet(exerciseName: String, weight: Double?, weightUnit: String, reps: Int) {
        lastCompletedExerciseName = exerciseName
        if let w = weight, w > 0 {
            let wStr = w.formattedWeight
            lastCompletedSetDisplay = "\(wStr)\(weightUnit) × \(reps)"
        } else {
            lastCompletedSetDisplay = "× \(reps)"
        }
        updateLiveActivity(isResting: isResting, restEndDate: currentRestEndDate)
    }

    func requestRepeatLastSet() {
        repeatLastSetRequested = true
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
    /// Repeats every `stillThereDelaySeconds` until the user takes any
    /// in-app action that calls `cancelStillThereNotification`
    /// (set logged, session ended/cancelled, etc.). This is what gives the
    /// "ping every 10 min while idle" cadence — the OS handles re-firing.
    private func scheduleStillThereNotification() {
        let center = UNUserNotificationCenter.current()
        cancelStillThereNotification()

        let content = UNMutableNotificationContent()
        content.title = "Still there?"
        content.body = "Your workout is waiting — get back to it!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.stillThereDelaySeconds,
            repeats: true
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

    // MARK: - Start Reminder

    /// Fires a local notification immediately reminding the user to start
    /// the session they just built. Only fires once per session — once
    /// you've gotten the nudge, more sets won't re-trigger it. No-ops if
    /// the workout is already underway.
    func scheduleStartReminder() {
        guard let sessionId, let sessionTitle, !isWorkoutStarted else { return }
        if startReminderFiredForSessionId == sessionId { return }
        startReminderFiredForSessionId = sessionId

        let content = UNMutableNotificationContent()
        content.title = "Ready to start?"
        content.body = "\(sessionTitle) is set up — tap to begin."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.startReminderId(for: sessionId),
            content: content,
            trigger: nil // nil trigger → deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelStartReminder() {
        guard let sessionId else { return }
        let id = Self.startReminderId(for: sessionId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
        if startReminderFiredForSessionId == sessionId {
            startReminderFiredForSessionId = nil
        }
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

        // Push updated state to Watch
        pushStateToWatch(exercises: exercises)

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
            liveActivityService.reconnectIfNeeded()
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
        lastSavedExercises = cached.exercises
        // Only restore feedback if user actually selected values
        if cached.effortLevel > 0 || cached.energyLevel > 0 || !cached.painDiscomfort.isEmpty {
            restoredFeedback = (cached.effortLevel, cached.energyLevel, cached.painDiscomfort)
            lastSavedFeedback = (cached.effortLevel, cached.energyLevel, cached.painDiscomfort)
        }
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: Self.cacheKey)
    }

    // MARK: - Watch Connectivity

    private func setupWatchCallbacks() {
        guard let watchService = watchConnectivityService else { return }

        watchService.onSetCompletion = { [weak self] exerciseId, setId, weight, reps in
            Task { @MainActor [weak self] in
                self?.handleWatchSetCompletion(exerciseId: exerciseId, setId: setId, weight: weight, reps: reps)
            }
        }

        watchService.onRestTimerAction = { [weak self] action in
            Task { @MainActor [weak self] in
                switch action {
                case .skip:
                    self?.skipRestTimer()
                case .extend30:
                    self?.addRestTime(30)
                case .start:
                    self?.startRestTimer()
                }
            }
        }

        watchService.onHeartRateBatch = { [weak self] batch in
            Task { @MainActor [weak self] in
                self?.handleWatchHeartRateBatch(batch)
            }
        }

        watchService.onWorkoutSummary = { [weak self] summary in
            Task { @MainActor [weak self] in
                self?.watchWorkoutSummary = summary
            }
        }

        watchService.onRequestSessionStart = { [weak self] requestType, planDayId in
            Task { @MainActor [weak self] in
                self?.handleWatchSessionStartRequest(requestType: requestType, planDayId: planDayId)
            }
        }
    }

    /// Called by SessionFlowViewModel after set completion to push state to Watch
    func pushStateToWatch(exercises: [ActiveSessionExercise]) {
        guard let watchService = watchConnectivityService,
              let sessionId, let sessionTitle, let startDate = sessionStartDate else { return }

        let watchExercises = exercises.map { ex in
            WatchExerciseState(
                id: ex.id,
                name: ex.name,
                muscleGroup: ex.muscleGroup,
                equipment: ex.equipment,
                sets: ex.sets.map { set in
                    WatchSetState(
                        id: set.id,
                        setNumber: set.setNumber,
                        weight: set.weight,
                        weightUnit: set.weightUnit,
                        reps: set.reps,
                        isCompleted: set.isCompleted
                    )
                },
                supersetGroupId: ex.supersetGroupId,
                supersetOrder: ex.supersetOrder,
                targetSets: ex.targetSets,
                targetReps: ex.targetReps
            )
        }

        let state = WatchSessionState(
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            elapsedSeconds: elapsedSeconds,
            sessionStartDate: startDate,
            exercises: watchExercises,
            isResting: isResting,
            restTimeRemaining: restTimeRemaining,
            restStartDate: restStartDate,
            restDurationSeconds: restDurationSeconds
        )

        watchService.pushSessionState(state)
    }

    func pushWatchSessionEnded() {
        watchConnectivityService?.pushSessionEnded()
    }

    func pushRestTickToWatch() {
        guard let remaining = restTimeRemaining else { return }
        watchConnectivityService?.pushRestTimerTick(remaining: remaining)
    }

    /// Whether the Watch is managing the HKWorkoutSession (real calories available)
    var isWatchManagingWorkout: Bool {
        watchConnectivityService?.isWatchSessionManagingWorkout ?? false
    }

    func pushTodayPlanToWatch(plannedWorkout: PlannedWorkoutResponse?) {
        guard let watchService = watchConnectivityService else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayLabel = formatter.string(from: Date())

        let plan: WatchTodayPlan
        if let pw = plannedWorkout {
            plan = WatchTodayPlan(
                dayLabel: dayLabel,
                sessionTitle: pw.sessionTitle,
                dayType: pw.type,
                muscleGroups: pw.muscleGroups ?? [],
                exercises: (pw.exercises ?? []).map {
                    WatchPlanExercise(name: $0.name, muscleGroup: $0.muscleGroup, setsDisplay: $0.setsDisplay)
                },
                planDayId: pw.planDayId
            )
        } else {
            plan = WatchTodayPlan(
                dayLabel: dayLabel,
                sessionTitle: nil,
                dayType: "rest",
                muscleGroups: [],
                exercises: [],
                planDayId: nil
            )
        }

        watchService.pushTodayPlan(plan)
    }

    // MARK: - Watch Incoming Handlers

    /// Callback set by SessionFlowViewModel to handle Watch set completions
    var onWatchSetCompletion: ((_ exerciseId: String, _ setId: String, _ weight: Double?, _ reps: Int) -> Void)?

    private func handleWatchSetCompletion(exerciseId: String, setId: String, weight: Double?, reps: Int) {
        onWatchSetCompletion?(exerciseId, setId, weight, reps)
    }

    private func handleWatchSessionStartRequest(requestType: String, planDayId: String?) {
        print("📱 handleWatchSessionStartRequest: type=\(requestType), planDayId=\(planDayId ?? "nil")")
        let networkService = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)

        requestSessionStart { [weak self] in
            guard let self else { return }

            do {
                let response: SessionResponse
                if requestType == "planned", let dayId = planDayId {
                    response = try await networkService.request(
                        PlanRouter.startPlanSession(dayId: dayId).endpoint,
                        responseType: SessionResponse.self
                    )
                } else {
                    response = try await networkService.request(
                        HomeRouter.createSession(title: "Watch Workout", type: "strength").endpoint,
                        responseType: SessionResponse.self
                    )
                }
                self.openSession(response)
            } catch {
                print("📱 Watch session start request failed: \(error)")
            }
        }
    }

    private var watchHeartRateSamples: [WatchHeartRateSample] = []

    private func handleWatchHeartRateBatch(_ batch: WatchHeartRateBatch) {
        watchHeartRateSamples.append(contentsOf: batch.samples)
    }
}
