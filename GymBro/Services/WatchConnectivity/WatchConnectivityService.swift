//
//  WatchConnectivityService.swift
//  GymBro
//
//  iPhone-side WatchConnectivity service. Pushes session state to Watch,
//  receives actions (set completions, rest timer, HR data) from Watch.
//

import Foundation
import WatchConnectivity
import Combine

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject, WatchConnectivityServiceProtocol {

    // MARK: - Published

    @Published private(set) var isWatchReachable = false
    @Published private(set) var isWatchSessionManagingWorkout = false

    // MARK: - Callbacks (set by ActiveSessionManager)

    var onSetCompletion: ((_ exerciseId: String, _ setId: String, _ weight: Double?, _ reps: Int) -> Void)?
    var onCardioStart: ((_ exerciseId: String) -> Void)?
    var onCardioCompletion: ((_ exerciseId: String, _ durationSeconds: Int, _ distanceMeters: Int?) -> Void)?
    var onRestTimerAction: ((_ action: WatchRestTimerAction) -> Void)?
    var onHeartRateBatch: ((_ batch: WatchHeartRateBatch) -> Void)?
    var onWorkoutSummary: ((_ summary: WatchWorkoutSummary) -> Void)?
    var onRequestSessionStart: ((_ requestType: String, _ planDayId: String?) -> Void)?

    // MARK: - Private

    private var wcSession: WCSession?

    // MARK: - Init

    nonisolated override init() {
        super.init()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
    }

    // MARK: - Push State to Watch

    func pushSessionState(_ state: WatchSessionState) {
        guard let session = wcSession, session.activationState == .activated else { return }

        var context = (try? session.applicationContext) ?? [:]
        if let data = try? JSONEncoder().encode(state) {
            context["sessionState"] = data
        }
        context.removeValue(forKey: "sessionEnded")

        // Application context: latest-wins, survives disconnection
        try? session.updateApplicationContext(context)

        // Also send as message for real-time if reachable
        if session.isReachable {
            let message = WatchMessageCoder.encode(type: .sessionStateUpdate, payload: state)
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("📱 Failed to send session state to Watch: \(error)")
            })
        }
    }

    func pushSessionEnded(completed: Bool) {
        guard let session = wcSession, session.activationState == .activated else { return }

        var context = (try? session.applicationContext) ?? [:]
        context["sessionEnded"] = true
        context[WatchMessageKey.sessionCompleted] = completed
        context.removeValue(forKey: "sessionState")
        try? session.updateApplicationContext(context)

        if session.isReachable {
            var message = WatchMessageCoder.encode(type: .sessionEnded)
            message[WatchMessageKey.sessionCompleted] = completed
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }

        isWatchSessionManagingWorkout = false
    }

    func pushRestTimerTick(remaining: Int) {
        guard let session = wcSession, session.isReachable else { return }
        let message = WatchMessageCoder.encodeRestTimerTick(remaining: remaining)
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    func pushTodayPlan(_ plan: WatchTodayPlan) {
        guard let session = wcSession, session.activationState == .activated else { return }
        var context = (try? session.applicationContext) ?? [:]
        if let data = try? JSONEncoder().encode(plan) {
            context["todayPlan"] = data
        }
        try? session.updateApplicationContext(context)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: @preconcurrency WCSessionDelegate {

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isWatchReachable = reachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isWatchReachable = reachable
        }
    }

    // MARK: - Receive Messages from Watch

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let msg = message
        Task { @MainActor in
            self.handleWatchMessage(msg)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping @Sendable ([String: Any]) -> Void) {
        let msg = message
        Task { @MainActor in
            self.handleWatchMessage(msg, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let info = userInfo
        Task { @MainActor in
            self.handleWatchMessage(info)
        }
    }

    @MainActor
    private func handleWatchMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let type = WatchMessageCoder.decodeType(from: message) else {
            print("📱 Watch message received but type could not be decoded: \(message.keys)")
            return
        }

        print("📱 Received Watch message: \(type.rawValue)")

        switch type {
        case .completeSet:
            let exerciseId = message[WatchMessageKey.exerciseId] as? String ?? ""
            let setId = message[WatchMessageKey.setId] as? String ?? ""
            let weight = message[WatchMessageKey.weight] as? Double
            let reps = message[WatchMessageKey.reps] as? Int ?? 0

            onSetCompletion?(exerciseId, setId, weight, reps)
            replyHandler?(["confirmed": true])

        case .startCardio:
            let exerciseId = message[WatchMessageKey.exerciseId] as? String ?? ""
            onCardioStart?(exerciseId)
            replyHandler?(["confirmed": true])

        case .completeCardio:
            let exerciseId = message[WatchMessageKey.exerciseId] as? String ?? ""
            let durationSeconds = message[WatchMessageKey.durationSeconds] as? Int ?? 0
            let distanceMeters = message[WatchMessageKey.distanceMeters] as? Int
            onCardioCompletion?(exerciseId, durationSeconds, distanceMeters)
            replyHandler?(["confirmed": true])

        case .restTimerAction:
            if let rawAction = message[WatchMessageKey.restAction] as? String,
               let action = WatchRestTimerAction(rawValue: rawAction) {
                onRestTimerAction?(action)
            }
            replyHandler?(["received": true])

        case .heartRateBatch:
            if let batch: WatchHeartRateBatch = WatchMessageCoder.decodePayload(WatchHeartRateBatch.self, from: message) {
                onHeartRateBatch?(batch)
            }

        case .watchWorkoutStarted:
            // Watch's HKWorkoutSession is live — it owns the HealthKit
            // workout for this session. SessionFlowViewModel checks this
            // (via ActiveSessionManager.isWatchManagingWorkout) to skip
            // the phone-side HKWorkout save that used to duplicate the
            // workout in Apple Fitness.
            isWatchSessionManagingWorkout = true
            replyHandler?(["received": true])

        case .workoutSummary:
            if let summary: WatchWorkoutSummary = WatchMessageCoder.decodePayload(WatchWorkoutSummary.self, from: message) {
                onWorkoutSummary?(summary)
                isWatchSessionManagingWorkout = false
            }

        case .requestSessionStart:
            let requestType = message[WatchMessageKey.requestType] as? String ?? "custom"
            let planDayId = message[WatchMessageKey.planDayId] as? String
            print("📱 Watch requested session start: type=\(requestType), planDayId=\(planDayId ?? "nil"), callback set=\(onRequestSessionStart != nil)")
            onRequestSessionStart?(requestType, planDayId)
            replyHandler?(["started": true])

        default:
            break
        }
    }
}
