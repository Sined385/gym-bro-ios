//
//  TrainingFrequencyView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine

/// Onboarding screen - Training frequency selection
struct TrainingFrequencyView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            // Header
            StepHeader(
                icon: "calendar",
                title: String(localized: "Weekly workout goal")
            )

            // Frequency selection cards
            VStack(spacing: 12) {
                ForEach(TrainingFrequency.allCases, id: \.self) { frequency in
                    SelectionCard(
                        title: frequency.label,
                        subtitle: frequency.displayName,
                        isSelected: viewModel.onboardingData.trainingFrequency == frequency,
                        onTap: {
                            viewModel.selectTrainingFrequency(frequency)
                        }
                    )
                }
            }
        }
    }
}
