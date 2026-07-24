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
    // Set when the session is opened for a plan day so the eventual
    // /complete-full call can link the new WorkoutSession row back to
    // its PlanDay. Nil for ad-hoc / Coach-created sessions.
    @Published var planDayId: String?
    @Published var sessionType: String?
    @Published var aiMessage: String?
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

    // sessionStartDate is the wall-clock instant when the workout
    // timer began. Used both for the elapsed-seconds timer and (on
    // completion) for the started_at field sent to /complete-full —
    // the server uses it to populate workout_sessions.started_at when
    // the session row is being created from scratch.
    @Published private(set) var sessionStartDate: Date?
    private var restStartDate: Date?
    private var restDurationSeconds: Int = 0
    private var foregroundCancellable: AnyCancellable?
    private var backgroundCancellable: AnyCancellable?

    // MARK: - Idle Auto-Complete

    /// Wall-clock of the last in-app activity during the workout. The idle
    /// auto-complete clock counts from here — once nothing has been done for
    /// `autoCompleteIdleSeconds`, the workout is wrapped up automatically.
    @Published private(set) var lastActivityDate: Date?
    /// Wall-clock of the most recently tracked set. Auto-complete uses this as
    /// the workout's END time, so the recorded duration is start → last set
    /// rather than start → (an hour of idling).
    private var lastSetTrackedDate: Date?
    /// Guards against re-entrant auto-completion while one is in flight.
    private var isAutoCompleting = false
    /// True when the session is being torn down after a real completion (vs a
    /// discard). Drives whether the Watch shows a summary. Reset on teardown.
    private var endedByCompletion = false
    private static let autoCompleteIdleSeconds: TimeInterval = 3600 // 1 hour
    private static let autoCompleteNotificationId = "gym-bro-auto-complete"

    // MARK: - Live Activity

    private let liveActivityService: LiveActivityService
    private(set) var lastCompletedExerciseName: String?
    private(set) var lastCompletedSetDisplay: String?
    /// The session-exercise id whose set was logged most recently. Backs the
    /// "tap the rest timer to jump back to the exercise you're on" shortcut.
    private(set) var lastExecutedExerciseId: String?
    @Published var repeatLastSetRequested: Bool = false

    // MARK: - Cardio Recording

    /// Recording state for the currently-running cardio exercise. Lives
    /// on the manager (not the view) so leaving and returning to
    /// CardioWorkoutView preserves elapsed time. Nil when no cardio
    /// exercise is being recorded. Cleared by `endCardio()` and when
    /// `endSession()` runs.
    struct CardioRecording: Equatable, Codable {
        let exerciseId: String
        /// Wall-clock when the current unpaused run started. Nil while paused.
        var startDate: Date?
        /// Seconds banked from prior unpaused runs (reset at Start, +delta at Pause).
        var accumulatedSeconds: Int
        var isPaused: Bool
    }

    @Published var cardioRecording: CardioRecording?

    /// The exercise id of the cardio that's currently being recorded,
    /// or nil when none is in flight. Used by the cardio screen to
    /// enforce "only one cardio at a time" — when this is set to a
    /// different exercise, the idle Start affordance is replaced with an
    /// "already in progress" notice instead of a second Start.
    var runningCardioExerciseId: String? { cardioRecording?.exerciseId }

    /// True if cardio is currently being recorded for `exerciseId` AND
    /// the user hasn't paused. Drives the family widget's TimelineView
    /// tick frequency.
    func isCardioActivelyRecording(for exerciseId: String) -> Bool {
        guard let rec = cardioRecording, rec.exerciseId == exerciseId else { return false }
        return !rec.isPaused && rec.startDate != nil
    }

    /// Begin recording for the given cardio exercise. Enforces a single
    /// in-flight cardio: if a *different* cardio is already recording (or
    /// paused), this is a no-op and returns `false` so it can never
    /// clobber another exercise's run. Calling it for the exercise that's
    /// already recording is also a no-op (returns `false`). Returns
    /// `true` only when a fresh recording was started.
    @discardableResult
    func startCardio(exerciseId: String) -> Bool {
        if let existing = cardioRecording {
            // Already recording something — only allow a true fresh start
            // when nothing is in flight. Same-exercise re-taps are ignored.
            _ = existing
            return false
        }
        cardioRecording = CardioRecording(
            exerciseId: exerciseId,
            startDate: Date(),
            accumulatedSeconds: 0,
            isPaused: false
        )
        persistCardioRecording()
        updateLiveActivity(isResting: isResting, restEndDate: currentRestEndDate)
        return true
    }

    /// Bank the active delta into `accumulatedSeconds` and pause.
    func pauseCardio() {
        guard var rec = cardioRecording else { return }
        if let started = rec.startDate, !rec.isPaused {
            rec.accumulatedSeconds += Int(Date().timeIntervalSince(started))
        }
        rec.startDate = nil
        rec.isPaused = true
        cardioRecording = rec
        persistCardioRecording()
        updateLiveActivity(isResting: isResting, restEndDate: currentRestEndDate)
    }

    /// Resume after a pause. Re-arms `startDate` to "now" so subsequent
    /// elapsed math just adds to `accumulatedSeconds`.
    func resumeCardio() {
        guard var rec = cardioRecording else { return }
        rec.startDate = Date()
        rec.isPaused = false
        cardioRecording = rec
        persistCardioRecording()
        updateLiveActivity(isResting: isResting, restEndDate: currentRestEndDate)
    }

    /// Lightweight save that just re-runs the cache write with the
    /// current exercises + cardioRecording. Used by the Start/Pause/
    /// Resume/End calls — without this, the cardioRecording lives only
    /// in memory and dies with the process.
    private func persistCardioRecording() {
        saveSession(
            exercises: lastSavedExercises ?? [],
            effortLevel: lastSavedFeedback?.effort ?? 0,
            energyLevel: lastSavedFeedback?.energy ?? 0,
            painDiscomfort: lastSavedFeedback?.pain ?? ""
        )
    }

    /// Returns the elapsed seconds at the given moment for the
    /// currently-recorded cardio. Zero when no recording is in flight.
    func currentCardioElapsed(at now: Date) -> Int {
        guard let rec = cardioRecording else { return 0 }
        if let started = rec.startDate, !rec.isPaused {
            return rec.accumulatedSeconds + Int(now.timeIntervalSince(started))
        }
        return rec.accumulatedSeconds
    }

    /// Finalize recording: returns the total elapsed seconds and clears
    /// the recording slot. The caller (CardioWorkoutView's Done tap)
    /// then writes that total into the SessionFlowViewModel via
    /// completeSet(... durationSeconds:).
    @discardableResult
    func endCardio() -> Int {
        let total = currentCardioElapsed(at: Date())
        cardioRecording = nil
        persistCardioRecording()
        updateLiveActivity(isResting: isResting, restEndDate: currentRestEndDate)
        return max(total, 0)
    }

    // MARK: - Watch Connectivity

    private let watchConnectivityService: WatchConnectivityServiceProtocol?
    @Published var watchWorkoutSummary: WatchWorkoutSummary?
    /// Average HR resolved at completion (`resolveSessionAverageHeartRate()`),
    /// cached so the post-workout share screen shows the same value that was
    /// persisted server-side instead of re-reading the racy Watch summary.
    @Published private(set) var lastResolvedHeartRate: Int?
    /// Phone-driven hint for the Watch: which exercise the user has actively
    /// open on the phone. Nil when no specific exercise view is open (plan
    /// view, library, etc.); the Watch then falls back to its "first
    /// incomplete" heuristic so watch-only flow keeps working.
    private(set) var phoneActiveExerciseId: String?

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

    func openSession(_ session: SessionResponse, planDayId: String? = nil, autoStart: Bool = true) {
        print("🟡 openSession called: \(session.title), autoStart=\(autoStart), liveActivityService = \(liveActivityService)")
        sessionId = session.id
        sessionTitle = session.title
        self.planDayId = planDayId
        sessionType = session.type
        aiMessage = session.aiMessage
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
        lastActivityDate = Date()
        lastSetTrackedDate = nil
        lastExecutedExerciseId = nil
        isAutoCompleting = false
        startTimer()
        scheduleStillThereNotification()
        liveActivityService.startActivity(
            title: title,
            startDate: sessionStartDate!,
            exerciseCount: exerciseCount
        )
        // Launch the Watch app with a workout configuration so it starts
        // its HKWorkoutSession even when closed — otherwise the Watch has
        // no idea a workout is running and watchOS keeps asking "Are you
        // working out?". The Watch reports back via watchWorkoutStarted,
        // which is what stops the phone writing a duplicate HKWorkout.
        Task {
            let healthKit = DependencyContainer.shared.resolve(HealthKitServiceProtocol.self)
            await healthKit.startWatchWorkoutApp()
        }
        Analytics.logEvent("workout_started", parameters: [:])
    }

    func refreshInactivityTimer() {
        cancelStillThereNotification()
        scheduleStillThereNotification()
    }

    // MARK: - Idle Auto-Complete

    /// Record that the user did something in the app during the workout —
    /// resets the 1-hour idle auto-complete clock. Called from set actions,
    /// rest-timer actions, and exercise navigation.
    func registerActivity() {
        guard isWorkoutStarted else { return }
        lastActivityDate = Date()
    }

    /// Stamp the time of the latest tracked set. This is the end point used
    /// for the auto-completed workout's duration. Also counts as activity.
    func registerSetTracked(exerciseId: String? = nil) {
        guard isWorkoutStarted else { return }
        lastSetTrackedDate = Date()
        lastActivityDate = Date()
        if let exerciseId { lastExecutedExerciseId = exerciseId }
    }

    /// If the workout has been idle for `autoCompleteIdleSeconds`, wrap it up
    /// (or discard it if nothing was tracked). Cheap; called from the 1s timer
    /// tick, on foreground, and after restoring a session on launch.
    private func checkAutoCompleteIfIdle() {
        guard isWorkoutStarted, !isAutoCompleting,
              let last = lastActivityDate,
              Date().timeIntervalSince(last) >= Self.autoCompleteIdleSeconds else { return }
        isAutoCompleting = true
        Task { @MainActor in await self.autoCompleteOrDiscardIdleSession() }
    }

    private func autoCompleteOrDiscardIdleSession() async {
        guard let sessionId, let start = sessionStartDate else {
            isAutoCompleting = false
            return
        }
        let exercises = lastSavedExercises ?? []
        let hasTrackedSet = exercises.contains { $0.sets.contains(where: \.isCompleted) }

        // Nothing logged the entire time — discard rather than save an empty workout.
        guard hasTrackedSet else {
            analyticsService.track("workout_auto_discarded", properties: [:])
            // Cancel the server row for ad-hoc / Coach sessions (plan-day
            // sessions have no server row under "store on complete").
            if planDayId == nil {
                let networkService = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
                Task {
                    _ = try? await networkService.request(
                        HomeRouter.cancelSession(sessionId: sessionId).endpoint,
                        responseType: SessionResponse.self,
                    )
                }
            }
            finishAndResetSession()
            return
        }

        // Duration runs start → last tracked set, NOT start → now.
        let endDate = lastSetTrackedDate ?? Date()
        let durationMinutes = max(1, Int(endDate.timeIntervalSince(start)) / 60)
        let avgHeartRate = await resolveSessionAverageHeartRate()

        let payload = SessionCompletionPayload(
            durationMinutes: durationMinutes,
            avgHeartRate: avgHeartRate,
            // Auto-completed workouts have no user feedback — use neutral defaults.
            feedback: SessionFeedback(effortLevel: 5, energyLevel: 3, painDiscomfort: "None"),
            exercises: exercises.map { ex in
                CompletionExercise(
                    name: ex.name,
                    muscleGroup: ex.muscleGroup,
                    stepNumber: ex.stepNumber,
                    sets: ex.sets.filter(\.isCompleted).map { set in
                        let isCardio = set.durationSeconds != nil
                        return CompletionSet(
                            setNumber: set.setNumber,
                            reps: set.reps ?? 0,
                            isCompleted: set.isCompleted,
                            weight: (set.isBodyweight || isCardio) ? nil : set.weight,
                            weightUnit: set.weightUnit,
                            isBodyweight: set.isBodyweight,
                            durationSeconds: set.durationSeconds,
                            distanceMeters: set.distanceMeters,
                            targetSpeedKmh: set.targetSpeedKmh
                        )
                    },
                    libraryExerciseId: ex.libraryExerciseId,
                    equipment: ex.equipment,
                    accentColor: ex.accentColor,
                    supersetGroupId: ex.supersetGroupId,
                    supersetOrder: ex.supersetOrder
                )
            },
            title: sessionTitle,
            type: sessionType,
            aiMessage: aiMessage,
            startedAt: start,
            planDayId: planDayId
        )

        // Persist to disk before the call so the completion survives app kill;
        // GymBroApp retries cached completions on the next foreground.
        let completionCache = DependencyContainer.shared.resolve(SessionCompletionCacheServiceProtocol.self)
        let pending = PendingSessionCompletion(
            id: UUID(),
            sessionId: sessionId,
            sessionTitle: sessionTitle ?? "Workout",
            payload: payload,
            createdAt: Date(),
            retryCount: 0,
            lastRetryAt: nil
        )
        completionCache.save(pending)

        let networkService = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
        do {
            let response = try await networkService.request(
                SessionRouter.completeSessionFull(sessionId: sessionId, payload: payload.toDictionary()).endpoint,
                responseType: SessionResponse.self
            )
            completionCache.remove(id: pending.id)
            analyticsService.track("workout_auto_completed", properties: [
                "duration_minutes": response.durationMinutes ?? durationMinutes,
                "exercise_count": exercises.count
            ] as [String: Any])
        } catch {
            // Left in the completion cache — the retry sweep will deliver it.
            print("[ActiveSession] auto-complete failed, cached for retry: \(error)")
        }

        sendAutoCompleteNotification()
        endedByCompletion = true
        finishAndResetSession()
    }

    private func sendAutoCompleteNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Workout saved"
        content.body = "You went quiet, so we wrapped up and saved your workout."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.autoCompleteNotificationId,
            content: content,
            trigger: nil // deliver now
        )
        UNUserNotificationCenter.current().add(request)
    }

    func expand() {
        presentationState = .expanded
        registerActivity()
    }

    func collapse() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        presentationState = .collapsed
        analyticsService.track("session_collapsed", properties: [:])
    }

    func endSession() {
        let wasActive = isWorkoutStarted
        let exerciseCount = lastSavedExercises?.count ?? 0
        if wasActive {
            analyticsService.track("workout_cancelled", properties: ["exercise_count": exerciseCount])
        }
        finishAndResetSession()
    }

    /// Tears down all session state (timers, live activity, watch, cache) and
    /// clears the manager back to "no active session". Shared by manual
    /// cancel (`endSession`), normal completion teardown, and idle
    /// auto-completion — none of which should leave the workout bar lingering.
    private func finishAndResetSession() {
        liveActivityService.endActivity()
        pushWatchSessionEnded(completed: endedByCompletion)
        stopTimer()
        skipRestTimer()
        cancelStillThereNotification()
        cancelStartReminder()
        presentationState = .hidden
        sessionId = nil
        sessionTitle = nil
        planDayId = nil
        sessionType = nil
        aiMessage = nil
        sessionExercises = []
        sessionStartDate = nil
        isWorkoutStarted = false
        lastSavedExercises = nil
        lastSavedFeedback = nil
        lastCompletedExerciseName = nil
        lastCompletedSetDisplay = nil
        repeatLastSetRequested = false
        cardioRecording = nil
        restoredExercises = nil
        restoredFeedback = nil
        watchWorkoutSummary = nil
        watchHeartRateSamples.removeAll()
        lastResolvedHeartRate = nil
        lastActivityDate = nil
        lastSetTrackedDate = nil
        lastExecutedExerciseId = nil
        isAutoCompleting = false
        endedByCompletion = false
        clearCache()
        // Fetch fresh dashboard data, not just bump the reload version.
        // TrainingPlanViewModel only refetches via reloadVersion when
        // planDays is empty — relying on that meant the Plan tab kept
        // stale `pending` status and pre-completion exercises after a
        // workout. refresh() pushes a new snapshot into AppDataState
        // which TrainingPlanVM picks up via its $planDays sink.
        Task { [appDataState] in
            await appDataState.refresh(reason: .sessionCompleted)
        }
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
        let abandonedSessionId = sessionId
        let abandonedPlanDayId = planDayId
        pendingSessionStart = nil
        showSessionConflict = false
        endSession()
        // For ad-hoc / Coach sessions (no plan day), the prior session
        // had a server row in 'proposed' or 'active'. Fire /cancel so it
        // doesn't sit orphan — the user's trace history would have a
        // cancelled row instead of a hanging active one that re-triggers
        // the conflict dialog forever. For plan-day sessions (no server
        // row under the "store on complete" flow), skip the API call.
        if let id = abandonedSessionId, abandonedPlanDayId == nil {
            let networkService = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
            Task {
                _ = try? await networkService.request(
                    HomeRouter.cancelSession(sessionId: id).endpoint,
                    responseType: SessionResponse.self,
                )
            }
        }
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
        // Piggyback the idle check on the 1s tick (foreground) and on the
        // foreground recalc — covers "app open but untouched" and "returned
        // after a long background".
        checkAutoCompleteIfIdle()
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
        registerActivity()
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
        registerActivity()
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
        // Cardio recording state — gives the Live Activity something to
        // show during a walk/row: a ticking elapsed timer anchored so
        // (now − anchor) == elapsed, or the frozen value while paused.
        var cardioName: String?
        var cardioAnchor: Date?
        var cardioPausedElapsed: Int?
        if let rec = cardioRecording {
            cardioName = lastSavedExercises?
                .first { $0.id == rec.exerciseId }?.name ?? "Cardio"
            let elapsed = currentCardioElapsed(at: Date())
            if rec.isPaused || rec.startDate == nil {
                cardioPausedElapsed = elapsed
            } else {
                cardioAnchor = Date().addingTimeInterval(-Double(elapsed))
            }
        }

        let state = WorkoutActivityAttributes.ContentState(
            isResting: isResting,
            restEndDate: restEndDate,
            lastExerciseName: lastCompletedExerciseName,
            lastSetDisplay: lastCompletedSetDisplay,
            totalSetsCompleted: lastSavedExercises?.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count } ?? 0,
            totalExercises: lastSavedExercises?.count ?? 0,
            cardioExerciseName: cardioName,
            cardioAnchorDate: cardioAnchor,
            cardioPausedElapsedSeconds: cardioPausedElapsed
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
        let planDayId: String?
        let sessionType: String?
        let aiMessage: String?
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
        /// In-flight cardio recording state — present when the user has
        /// tapped Start on a cardio exercise and not yet tapped Done.
        /// Survives app kill so reopening lands the user back on the
        /// recording state with the timer correctly advanced from
        /// `startDate`.
        let cardioRecording: CardioRecording?
        /// Idle auto-complete state — so a relaunch after a long idle still
        /// knows when the user last did something / last tracked a set.
        let lastActivityDate: Date?
        let lastSetTrackedDate: Date?

        // Older builds wrote payloads without the new metadata. Decode
        // them gracefully so a TestFlight upgrade doesn't lose an
        // in-progress workout.
        enum CodingKeys: String, CodingKey {
            case sessionId, sessionTitle, planDayId, sessionType, aiMessage,
                 sessionStartDate, exercises, sessionExercises,
                 presentationState, effortLevel, energyLevel, painDiscomfort,
                 restStartDate, restDurationSeconds, isWorkoutStarted,
                 cardioRecording, lastActivityDate, lastSetTrackedDate
        }

        init(
            sessionId: String,
            sessionTitle: String,
            planDayId: String?,
            sessionType: String?,
            aiMessage: String?,
            sessionStartDate: Date?,
            exercises: [ActiveSessionExercise],
            sessionExercises: [DashboardExercise],
            presentationState: String,
            effortLevel: Int,
            energyLevel: Int,
            painDiscomfort: String,
            restStartDate: Date?,
            restDurationSeconds: Int,
            isWorkoutStarted: Bool,
            cardioRecording: CardioRecording?,
            lastActivityDate: Date?,
            lastSetTrackedDate: Date?
        ) {
            self.sessionId = sessionId
            self.sessionTitle = sessionTitle
            self.planDayId = planDayId
            self.sessionType = sessionType
            self.aiMessage = aiMessage
            self.sessionStartDate = sessionStartDate
            self.exercises = exercises
            self.sessionExercises = sessionExercises
            self.presentationState = presentationState
            self.effortLevel = effortLevel
            self.energyLevel = energyLevel
            self.painDiscomfort = painDiscomfort
            self.restStartDate = restStartDate
            self.restDurationSeconds = restDurationSeconds
            self.isWorkoutStarted = isWorkoutStarted
            self.cardioRecording = cardioRecording
            self.lastActivityDate = lastActivityDate
            self.lastSetTrackedDate = lastSetTrackedDate
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.sessionId = try c.decode(String.self, forKey: .sessionId)
            self.sessionTitle = try c.decode(String.self, forKey: .sessionTitle)
            self.planDayId = try c.decodeIfPresent(String.self, forKey: .planDayId)
            self.sessionType = try c.decodeIfPresent(String.self, forKey: .sessionType)
            self.aiMessage = try c.decodeIfPresent(String.self, forKey: .aiMessage)
            self.sessionStartDate = try c.decodeIfPresent(Date.self, forKey: .sessionStartDate)
            self.exercises = try c.decode([ActiveSessionExercise].self, forKey: .exercises)
            self.sessionExercises = try c.decode([DashboardExercise].self, forKey: .sessionExercises)
            self.presentationState = try c.decode(String.self, forKey: .presentationState)
            self.effortLevel = try c.decode(Int.self, forKey: .effortLevel)
            self.energyLevel = try c.decode(Int.self, forKey: .energyLevel)
            self.painDiscomfort = try c.decode(String.self, forKey: .painDiscomfort)
            self.restStartDate = try c.decodeIfPresent(Date.self, forKey: .restStartDate)
            self.restDurationSeconds = try c.decode(Int.self, forKey: .restDurationSeconds)
            self.isWorkoutStarted = try c.decode(Bool.self, forKey: .isWorkoutStarted)
            self.cardioRecording = try c.decodeIfPresent(CardioRecording.self, forKey: .cardioRecording)
            self.lastActivityDate = try c.decodeIfPresent(Date.self, forKey: .lastActivityDate)
            self.lastSetTrackedDate = try c.decodeIfPresent(Date.self, forKey: .lastSetTrackedDate)
        }
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
            planDayId: planDayId,
            sessionType: sessionType,
            aiMessage: aiMessage,
            sessionStartDate: sessionStartDate,
            exercises: exercises,
            sessionExercises: sessionExercises,
            presentationState: stateString,
            effortLevel: effortLevel,
            energyLevel: energyLevel,
            painDiscomfort: painDiscomfort,
            restStartDate: restStartDate,
            restDurationSeconds: restDurationSeconds,
            isWorkoutStarted: isWorkoutStarted,
            cardioRecording: cardioRecording,
            lastActivityDate: lastActivityDate,
            lastSetTrackedDate: lastSetTrackedDate
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
        planDayId = cached.planDayId
        sessionType = cached.sessionType
        aiMessage = cached.aiMessage
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
        cardioRecording = cached.cardioRecording
        lastActivityDate = cached.lastActivityDate
        lastSetTrackedDate = cached.lastSetTrackedDate
        // Only restore feedback if user actually selected values
        if cached.effortLevel > 0 || cached.energyLevel > 0 || !cached.painDiscomfort.isEmpty {
            restoredFeedback = (cached.effortLevel, cached.energyLevel, cached.painDiscomfort)
            lastSavedFeedback = (cached.effortLevel, cached.energyLevel, cached.painDiscomfort)
        }

        // Relaunched after a long idle? Wrap up immediately.
        if isWorkoutStarted {
            checkAutoCompleteIfIdle()
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

        watchService.onCardioStart = { [weak self] exerciseId in
            Task { @MainActor [weak self] in
                // Start the phone's recording clock so both devices share one
                // source of truth; this pushes updated state back to the Watch.
                _ = self?.startCardio(exerciseId: exerciseId)
            }
        }

        watchService.onCardioCompletion = { [weak self] exerciseId, durationSeconds, distanceMeters in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Clear the recording slot (so the Watch leaves the recording
                // phase). Prefer the Watch's frozen duration — it was captured
                // when the user tapped Done, before the distance-entry sheet,
                // so endCardio() here would over-count by the entry time.
                let recorded = self.endCardio()
                let duration = durationSeconds > 0 ? durationSeconds : recorded
                self.onWatchCardioCompletion?(exerciseId, duration, distanceMeters)
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
                // Localized on the phone side — the Watch has no
                // translation map of its own.
                name: localizedExerciseName(ex.name, externalId: ex.externalId),
                muscleGroup: ex.muscleGroup,
                equipment: ex.equipment,
                sets: ex.sets.map { set in
                    WatchSetState(
                        id: set.id,
                        setNumber: set.setNumber,
                        weight: set.weight,
                        weightUnit: set.weightUnit,
                        reps: set.reps,
                        isCompleted: set.isCompleted,
                        durationSeconds: set.durationSeconds
                    )
                },
                supersetGroupId: ex.supersetGroupId,
                supersetOrder: ex.supersetOrder,
                targetSets: ex.targetSets,
                targetReps: ex.targetReps,
                isCardio: ex.muscleGroup.caseInsensitiveCompare("Cardio") == .orderedSame
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
            restDurationSeconds: restDurationSeconds,
            activeExerciseId: phoneActiveExerciseId,
            cardioRecordingExerciseId: cardioRecording?.exerciseId,
            cardioRecordingStartDate: cardioRecording?.startDate,
            cardioRecordingAccumulatedSeconds: cardioRecording?.accumulatedSeconds
        )

        watchService.pushSessionState(state)
        lastSavedExercises = exercises
    }

    /// Sets the exercise the user has open on the phone. Pushes the updated
    /// state to the Watch so it follows along. Passing nil clears the pin
    /// (e.g. when the user navigates back to the plan view) — the Watch then
    /// reverts to its "first incomplete" heuristic.
    func setPhoneActiveExercise(_ exerciseId: String?) {
        guard phoneActiveExerciseId != exerciseId else { return }
        registerActivity()
        phoneActiveExerciseId = exerciseId
        guard let exercises = lastSavedExercises, isSessionActive else { return }
        pushStateToWatch(exercises: exercises)
    }

    func pushWatchSessionEnded(completed: Bool) {
        watchConnectivityService?.pushSessionEnded(completed: completed)
    }

    /// Marks the imminent teardown as a real completion (feedback submit / auto
    /// -complete) so the Watch shows its summary. A discard leaves this false
    /// and the Watch silently clears instead of flashing a "completed" summary.
    func markSessionCompleted() { endedByCompletion = true }

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
    var onWatchCardioCompletion: ((_ exerciseId: String, _ durationSeconds: Int, _ distanceMeters: Int?) -> Void)?

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
                let resolvedPlanDayId: String?
                if requestType == "planned", let dayId = planDayId {
                    response = try await networkService.request(
                        PlanRouter.startPlanSession(dayId: dayId).endpoint,
                        responseType: SessionResponse.self
                    )
                    resolvedPlanDayId = dayId
                } else {
                    response = try await networkService.request(
                        HomeRouter.createSession(title: "Watch Workout", type: "strength").endpoint,
                        responseType: SessionResponse.self
                    )
                    resolvedPlanDayId = nil
                }
                self.openSession(response, planDayId: resolvedPlanDayId)
            } catch {
                print("📱 Watch session start request failed: \(error)")
            }
        }
    }

    private var watchHeartRateSamples: [WatchHeartRateSample] = []

    private func handleWatchHeartRateBatch(_ batch: WatchHeartRateBatch) {
        watchHeartRateSamples.append(contentsOf: batch.samples)
    }

    /// Average heart rate for the current session, used at completion to
    /// persist `avg_heart_rate` server-side. Prefers the Watch's own
    /// workout-summary average (HealthKit-derived) when available; falls
    /// back to averaging the streamed sample batches. Returns nil when no
    /// Watch was paired or no samples arrived — keeps the column null
    /// rather than logging a meaningless 0.
    var sessionAverageHeartRate: Int? {
        if let summary = watchWorkoutSummary?.averageHeartRate, summary > 0 {
            return Int(summary.rounded())
        }
        guard !watchHeartRateSamples.isEmpty else { return nil }
        let total = watchHeartRateSamples.reduce(0.0) { $0 + $1.bpm }
        return Int((total / Double(watchHeartRateSamples.count)).rounded())
    }

    /// Resolves the session's average heart rate at completion time.
    ///
    /// The Watch sends its end-of-workout summary asynchronously a beat AFTER
    /// `pushWatchSessionEnded()`, so reading `sessionAverageHeartRate` inline at
    /// completion races the summary and usually loses. This:
    ///   1. briefly awaits the summary when the Watch was streaming this session,
    ///   2. falls back to averaging the streamed sample batches,
    ///   3. falls back to a direct HealthKit query over the session window — so a
    ///      plain Apple Watch workout (HR in Apple Health, even without the
    ///      GymJam Watch app live) still records a value.
    /// Caches the result in `lastResolvedHeartRate` for the share screen.
    @discardableResult
    func resolveSessionAverageHeartRate() async -> Int? {
        // Only wait if the Watch actually streamed — otherwise non-Watch users
        // would eat the delay for nothing.
        if watchWorkoutSummary == nil, !watchHeartRateSamples.isEmpty {
            for _ in 0..<12 { // up to ~3s, broken early the moment it lands
                try? await Task.sleep(nanoseconds: 250_000_000)
                if watchWorkoutSummary != nil { break }
            }
        }

        if let hr = sessionAverageHeartRate {
            lastResolvedHeartRate = hr
            return hr
        }

        // No Watch-derived value — best-effort HealthKit query for the window.
        if let start = sessionStartDate {
            let healthKit = DependencyContainer.shared.resolve(HealthKitServiceProtocol.self)
            if let avg = try? await healthKit.fetchAverageHeartRate(from: start, to: Date()),
               avg > 0 {
                lastResolvedHeartRate = Int(avg.rounded())
                return lastResolvedHeartRate
            }
        }

        lastResolvedHeartRate = nil
        return nil
    }
}
