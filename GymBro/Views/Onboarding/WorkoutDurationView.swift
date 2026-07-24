//
//  WorkoutDurationView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine

/// Onboarding screen - Workout duration selection
struct WorkoutDurationView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            // Header
            StepHeader(
                icon: "clock.fill",
                title: String(localized: "Preferred workout duration?")
            )

            // Duration selection cards
            VStack(spacing: 12) {
                ForEach(WorkoutDuration.allCases, id: \.self) { duration in
                    SelectionCard(
                        title: duration.displayName,
                        isSelected: viewModel.onboardingData.workoutDuration == duration,
                        onTap: {
                            viewModel.selectWorkoutDuration(duration)
                        }
                    )
                }
            }
        }
    }
}
