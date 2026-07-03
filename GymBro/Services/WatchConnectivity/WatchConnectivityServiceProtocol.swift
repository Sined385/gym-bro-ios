//
//  WatchConnectivityServiceProtocol.swift
//  GymBro
//
//  Protocol for Watch connectivity to enable testability.
//

import Foundation

protocol WatchConnectivityServiceProtocol: AnyObject {
    var isWatchReachable: Bool { get }
    var isWatchSessionManagingWorkout: Bool { get }

    func activate()
    func pushSessionState(_ state: WatchSessionState)
    func pushSessionEnded(completed: Bool)
    func pushRestTimerTick(remaining: Int)
    func pushTodayPlan(_ plan: WatchTodayPlan)

    var onSetCompletion: ((_ exerciseId: String, _ setId: String, _ weight: Double?, _ reps: Int) -> Void)? { get set }
    var onCardioStart: ((_ exerciseId: String) -> Void)? { get set }
    var onCardioCompletion: ((_ exerciseId: String, _ durationSeconds: Int, _ distanceMeters: Int?) -> Void)? { get set }
    var onRestTimerAction: ((_ action: WatchRestTimerAction) -> Void)? { get set }
    var onHeartRateBatch: ((_ batch: WatchHeartRateBatch) -> Void)? { get set }
    var onWorkoutSummary: ((_ summary: WatchWorkoutSummary) -> Void)? { get set }
    var onRequestSessionStart: ((_ requestType: String, _ planDayId: String?) -> Void)? { get set }
}
