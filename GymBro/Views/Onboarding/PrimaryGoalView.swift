//
//  PrimaryGoalView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine

/// Onboarding screen - Primary fitness goal selection (multi-select)
struct PrimaryGoalView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            // Header
            StepHeader(
                icon: "target",
                title: "What are your goals?"
            )

            // Goal selection cards
            VStack(spacing: 12) {
                ForEach(PrimaryGoal.allCases, id: \.self) { goal in
                    SelectionCard(
                        title: goal.displayName,
                        isSelected: viewModel.onboardingData.primaryGoals.contains(goal),
                        showCheckmark: true,
                        onTap: {
                            viewModel.togglePrimaryGoal(goal)
                        }
                    )
                }
            }
        }
    }
}
