//
//  WatchDependencyContainer.swift
//  GymJamWatch
//
//  Lightweight manual DI container for Watch app.
//

import SwiftUI
import Combine

@MainActor
final class WatchDependencyContainer: ObservableObject {

    let connectivityService: PhoneConnectivityService
    let workoutService: WatchWorkoutService
    let sessionViewModel: WatchSessionViewModel
    let restTimerViewModel: WatchRestTimerViewModel
    let setLoggingViewModel: WatchSetLoggingViewModel

    init() {
        let connectivity = PhoneConnectivityService()
        let workout = WatchWorkoutService()

        let sessionVM = WatchSessionViewModel(
            connectivityService: connectivity,
            workoutService: workout
        )
        let restTimerVM = WatchRestTimerViewModel(connectivityService: connectivity)
        let setLoggingVM = WatchSetLoggingViewModel(connectivityService: connectivity)

        self.connectivityService = connectivity
        self.workoutService = workout
        self.sessionViewModel = sessionVM
        self.restTimerViewModel = restTimerVM
        self.setLoggingViewModel = setLoggingVM
    }
}
