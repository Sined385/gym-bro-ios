//
//  ExperienceLevelView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine

/// Onboarding screen - Experience level selection
struct ExperienceLevelView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            // Header
            StepHeader(
                icon: "dumbbell.fill",
                title: String(localized: "What is your experience level?")
            )

            // Experience level selection cards
            VStack(spacing: 12) {
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    SelectionCard(
                        title: level.displayName,
                        subtitle: level.subtitle,
                        isSelected: viewModel.onboardingData.experienceLevel == level,
                        onTap: {
                            viewModel.selectExperienceLevel(level)
                        }
                    )
                }
            }
        }
    }
}
