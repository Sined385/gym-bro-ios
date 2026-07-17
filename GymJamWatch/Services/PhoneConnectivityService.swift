//
//  PhoneConnectivityService.swift
//  GymJamWatch
//
//  WCSessionDelegate on Watch side — receives state from iPhone, sends actions back.
//

import Foundation
@preconcurrency import WatchConnectivity
import Combine

/// Wrapper to allow non-Sendable values to cross isolation boundaries safely.
struct UncheckedSendableBox<T>: @unchecked Sendable { let value: T }

@MainActor
final class PhoneConnectivityService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var sessionState: WatchSessionState?
    @Published var todayPlan: WatchTodayPlan?
    @Published var isPhoneReachable = false
    @Published var isSessionActive = false
    @Published var isRequestingSession = false

    // MARK: - Callbacks

    var onSetCompletionConfirmed: ((_ exerciseId: String, _ setId: String, _ weight: Double?, _ reps: Int) -> Void)?
    var onRestTimerTick: ((Int) -> Void)?
    /// Bool = the session was really completed (show summary). false = discard
    /// (silently clear, no summary).
    var onSessionEnded: ((Bool) -> Void)?

    // MARK: - Private

    private var wcSession: WCSession?
    private var pendingUserInfoTransfers: [[String: Any]] = []
    private var requestTimeoutTimer: Timer?

    // MARK: - Init

    nonisolated override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
    }

    // MARK: - Send Actions to iPhone

    func sendRequestSessionStart(type: String, planDayId: String? = nil) {
        let message = WatchMessageCoder.encodeRequestSessionStart(requestType: type, planDayId: planDayId)
        guard let session = wcSession else { return }

        isRequestingSession = true

        // Timeout: reset requesting state after 15s if no session arrives
        requestTimeoutTimer?.invalidate()
        requestTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRequestingSession else { return }
                self.isRequestingSession = false
                WatchHaptics.error()
            }
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: { @Sendable [weak self] reply in
                let started = reply["started"] as? Bool ?? false
                Task { @MainActor [weak self] in
                    if !started {
                        self?.isRequestingSession = false
                        self?.requestTimeoutTimer?.invalidate()
                    }
                }
            }, errorHandler: { @Sendable error in
                print("⌚ sendMessage timed out, falling back to transferUserInfo: \(error)")
                // Guaranteed delivery — iPhone will process when it wakes
                session.transferUserInfo(message)
            })
        } else {
            // Phone not reachable — queue for guaranteed delivery
            session.transferUserInfo(message)
        }
    }

    func sendSetCompletion(exerciseId: String, setId: String, weight: Double?, reps: Int) {
        let message = WatchMessageCoder.encodeSetCompletion(
            exerciseId: exerciseId,
            setId: setId,
            weight: weight,
            reps: reps
        )

        guard let session = wcSession, session.isReachable else {
            // Queue for guaranteed delivery
            pendingUserInfoTransfers.append(message)
            transferPendingUserInfo()
            return
        }

        session.sendMessage(message, replyHandler: { @Sendable [weak self] reply in
            let confirmed = reply["confirmed"] as? Bool ?? false
            Task { @MainActor [weak self] in
                if confirmed {
                    self?.onSetCompletionConfirmed?(exerciseId, setId, weight, reps)
                }
            }
        }, errorHandler: { @Sendable error in
            print("⌚ Failed to send set completion: \(error)")
            // Fallback to guaranteed delivery
            session.transferUserInfo(message)
        })
    }

    func sendStartCardio(exerciseId: String) {
        let message = WatchMessageCoder.encodeStartCardio(exerciseId: exerciseId)
        guard let session = wcSession, session.isReachable else {
            pendingUserInfoTransfers.append(message)
            transferPendingUserInfo()
            return
        }
        session.sendMessage(message, replyHandler: nil, errorHandler: { @Sendable error in
            print("⌚ Failed to send start cardio: \(error)")
            session.transferUserInfo(message)
        })
    }

    func sendCardioCompletion(exerciseId: String, durationSeconds: Int, distanceMeters: Int?) {
        let message = WatchMessageCoder.encodeCardioCompletion(
            exerciseId: exerciseId,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters
        )

        guard let session = wcSession, session.isReachable else {
            // Queue for guaranteed delivery
            pendingUserInfoTransfers.append(message)
            transferPendingUserInfo()
            return
        }

        session.sendMessage(message, replyHandler: nil, errorHandler: { @Sendable error in
            print("⌚ Failed to send cardio completion: \(error)")
            session.transferUserInfo(message)
        })
    }

    func sendRestTimerAction(_ action: WatchRestTimerAction) {
        let message = WatchMessageCoder.encodeRestTimerAction(action)
        guard let session = wcSession else { return }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { @Sendable error in
                print("⌚ Failed to send rest timer action: \(error)")
                // Fallback to guaranteed delivery
                session.transferUserInfo(message)
            })
        } else {
            // Guaranteed delivery when phone unreachable
            session.transferUserInfo(message)
        }
    }

    func sendHeartRateBatch(_ batch: WatchHeartRateBatch) {
        guard let data = try? JSONEncoder().encode(batch) else { return }
        let userInfo: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.heartRateBatch.rawValue,
            WatchMessageKey.payload: data
        ]
        wcSession?.transferUserInfo(userInfo)
    }

    /// Tell the phone the Watch's HKWorkoutSession is running, so the
    /// phone skips its own HKWorkout save at completion (the duplicate-
    /// workout bug was both sides writing to HealthKit).
    func sendWorkoutStarted() {
        let userInfo: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.watchWorkoutStarted.rawValue
        ]
        guard let session = wcSession, session.isReachable else {
            wcSession?.transferUserInfo(userInfo)
            return
        }
        session.sendMessage(userInfo, replyHandler: nil, errorHandler: { @Sendable _ in
            session.transferUserInfo(userInfo)
        })
    }

    func sendWorkoutSummary(_ summary: WatchWorkoutSummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        let userInfo: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.workoutSummary.rawValue,
            WatchMessageKey.payload: data
        ]

        guard let session = wcSession, session.isReachable else {
            wcSession?.transferUserInfo(userInfo)
            return
        }

        session.sendMessage(userInfo, replyHandler: nil, errorHandler: { @Sendable _ in
            session.transferUserInfo(userInfo)
        })
    }

    // MARK: - Private

    private func transferPendingUserInfo() {
        guard let session = wcSession else { return }
        for info in pendingUserInfoTransfers {
            session.transferUserInfo(info)
        }
        pendingUserInfoTransfers.removeAll()
    }

    private func handleReceivedContext(_ context: [String: Any]) {
        // Session state
        if let data = context["sessionState"] as? Data {
            if let state = try? JSONDecoder().decode(WatchSessionState.self, from: data) {
                Task { @MainActor in
                    self.sessionState = state
                    self.isSessionActive = true
                    self.isRequestingSession = false
                    self.requestTimeoutTimer?.invalidate()
                }
            }
        } else if context["sessionEnded"] as? Bool == true {
            let completed = context[WatchMessageKey.sessionCompleted] as? Bool ?? false
            Task { @MainActor in
                self.sessionState = nil
                self.isSessionActive = false
                self.onSessionEnded?(completed)
            }
        }

        // Today plan
        if let data = context["todayPlan"] as? Data {
            if let plan = try? JSONDecoder().decode(WatchTodayPlan.self, from: data) {
                Task { @MainActor in
                    self.todayPlan = plan
                }
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityService: @preconcurrency WCSessionDelegate {

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        let context = UncheckedSendableBox(value: session.receivedApplicationContext)
        Task { @MainActor in
            self.isPhoneReachable = reachable
            if !context.value.isEmpty {
                self.handleReceivedContext(context.value)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isPhoneReachable = reachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let ctx = UncheckedSendableBox(value: applicationContext)
        Task { @MainActor in
            self.handleReceivedContext(ctx.value)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let msg = UncheckedSendableBox(value: message)
        Task { @MainActor in
            self.handleIncomingMessage(msg.value)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let msg = UncheckedSendableBox(value: message)
        let handler = UncheckedSendableBox(value: replyHandler)
        Task { @MainActor in
            self.handleIncomingMessage(msg.value)
            handler.value(["received": true])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let info = UncheckedSendableBox(value: userInfo)
        Task { @MainActor in
            self.handleIncomingMessage(info.value)
        }
    }

    @MainActor
    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let type = WatchMessageCoder.decodeType(from: message) else { return }

        switch type {
        case .sessionStateUpdate:
            if let data = message[WatchMessageKey.payload] as? Data,
               let state = try? JSONDecoder().decode(WatchSessionState.self, from: data) {
                self.sessionState = state
                self.isSessionActive = true
                self.isRequestingSession = false
                self.requestTimeoutTimer?.invalidate()
            }

        case .restTimerTick:
            if let remaining = message[WatchMessageKey.remaining] as? Int {
                onRestTimerTick?(remaining)
            }

        case .sessionEnded:
            let completed = message[WatchMessageKey.sessionCompleted] as? Bool ?? false
            self.sessionState = nil
            self.isSessionActive = false
            onSessionEnded?(completed)

        case .todayPlanUpdate:
            if let data = message[WatchMessageKey.payload] as? Data,
               let plan = try? JSONDecoder().decode(WatchTodayPlan.self, from: data) {
                self.todayPlan = plan
            }

        default:
            break
        }
    }
}
