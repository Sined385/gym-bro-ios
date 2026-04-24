//
//  ActiveWorkoutView.swift
//  GymJamWatch
//
//  TabView with pages: Exercise | Rest Timer | Heart Rate during active workout.
//

import SwiftUI

struct ActiveWorkoutView: View {

    @EnvironmentObject var sessionViewModel: WatchSessionViewModel
    @EnvironmentObject var restTimerViewModel: WatchRestTimerViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ExerciseView()
                .tag(0)

            RestTimerView()
                .tag(1)

            HeartRateView()
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: restTimerViewModel.isActive) { _, isActive in
            // Auto-switch to rest timer when it starts
            if isActive {
                withAnimation { selectedTab = 1 }
            }
        }
        .onChange(of: restTimerViewModel.isFinished) { _, finished in
            if finished {
                withAnimation { selectedTab = 1 }
            }
        }
    }
}
