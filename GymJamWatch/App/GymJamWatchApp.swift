//
//  GymJamWatchApp.swift
//  GymJamWatch
//
//  Entry point for the GymJam watchOS companion app.
//

import SwiftUI
import WatchConnectivity
import WatchKit
import HealthKit

@main
struct GymJamWatchApp: App {

    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @StateObject private var container = WatchDependencyContainer()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(container.sessionViewModel)
                .environmentObject(container.restTimerViewModel)
                .environmentObject(container.setLoggingViewModel)
                .environmentObject(container.connectivityService)
        }
    }
}

/// Handles the HKHealthStore.startWatchApp launch: when a workout starts
/// on the phone, watchOS launches this app in the background and hands it
/// the workout configuration here. Starting the HKWorkoutSession from
/// this callback is what makes the Watch "know" a workout is ongoing —
/// live HR, ring credit, and no more "Are you working out?" prompts —
/// even when the user never opens the Watch app.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            guard let workoutService = WatchDependencyContainer.shared?.workoutService else { return }
            await workoutService.requestAuthorization()
            // Idempotent — if the WCSession state push already started
            // the workout, this is a no-op.
            await workoutService.startWorkout()
        }
    }
}
