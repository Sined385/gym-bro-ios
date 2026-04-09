//
//  LiveActivityService.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-07.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {

    private var currentActivity: Activity<WorkoutActivityAttributes>?

    func startActivity(title: String, startDate: Date, exerciseCount: Int) {
        let authInfo = ActivityAuthorizationInfo()
        print("🟡 LiveActivity: areActivitiesEnabled = \(authInfo.areActivitiesEnabled), frequentPushesEnabled = \(authInfo.frequentPushesEnabled)")
        guard authInfo.areActivitiesEnabled else {
            print("🔴 LiveActivity: Activities NOT enabled — check Settings > GymJam > Live Activities")
            return
        }

        let attributes = WorkoutActivityAttributes(
            sessionTitle: title,
            sessionStartDate: startDate
        )
        let initialState = WorkoutActivityAttributes.ContentState(
            isResting: false,
            restEndDate: nil,
            lastExerciseName: nil,
            lastSetDisplay: nil,
            totalSetsCompleted: 0,
            totalExercises: exerciseCount
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("🟢 LiveActivity: Started successfully, id = \(activity.id)")
        } catch {
            print("🔴 LiveActivity: Failed to start — \(error)")
        }
    }

    func updateActivity(state: WorkoutActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func endActivity() {
        guard let activity = currentActivity else { return }
        let activityToEnd = activity
        currentActivity = nil
        Task {
            await activityToEnd.end(nil, dismissalPolicy: .immediate)
        }
    }

    func reconnectIfNeeded() {
        let activities = Activity<WorkoutActivityAttributes>.activities
        currentActivity = activities.first
    }
}
