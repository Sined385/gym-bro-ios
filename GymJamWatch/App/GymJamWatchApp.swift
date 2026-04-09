//
//  GymJamWatchApp.swift
//  GymJamWatch
//
//  Entry point for the GymJam watchOS companion app.
//

import SwiftUI
import WatchConnectivity

@main
struct GymJamWatchApp: App {

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
