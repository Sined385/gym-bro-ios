//
//  PrimarySportView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine

/// Onboarding screen - Primary sport selection (multi-select)
struct PrimarySportView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    // Preset sport options
    private let presetSports = [
        "Gym / Weightlifting",
        "Running",
        "Cycling",
        "Swimming",
        "CrossFit"
    ]

    private var customSports: [String] {
        viewModel.onboardingData.primarySports.filter { !presetSports.contains($0) }
    }

    private var hasCustomSports: Bool {
        !customSports.isEmpty
    }

    var body: some View {
        VStack(spacing: 32) {
            // Header
            StepHeader(
                icon: "waveform.path.ecg",
                title: "What sports do you do?"
            )

            // Sport selection cards
            VStack(spacing: 12) {
                // Preset options
                ForEach(presetSports, id: \.self) { sport in
                    SelectionCard(
                        title: sport,
                        isSelected: viewModel.onboardingData.primarySports.contains(sport),
                        showCheckmark: true,
                        onTap: {
                            viewModel.togglePrimarySport(sport)
                        }
                    )
                }

                // "Other (Custom)" option with checkmark
                SelectionCard(
                    title: "Other (Custom)",
                    isSelected: viewModel.showCustomInput || hasCustomSports,
                    showCheckmark: true,
                    onTap: {
                        if viewModel.showCustomInput {
                            viewModel.hideCustomInputField()
                        } else {
                            viewModel.showCustomInputField()
                        }
                    }
                )

                // Show already-added custom sports
                if hasCustomSports {
                    ForEach(customSports, id: \.self) { sport in
                        HStack(spacing: 10) {
                            Text(sport)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.gymBroNeutral900)

                            Spacer()

                            Button {
                                viewModel.togglePrimarySport(sport)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gymBroNeutral400)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                        .background(Color.gymBroPrimary.opacity(0.06))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gymBroPrimary.opacity(0.3), lineWidth: 1)
                        )
                    }
                }

                // Custom input field when "Other" is selected
                if viewModel.showCustomInput {
                    CustomTextField(
                        placeholder: "Please specify...",
                        text: $viewModel.customInputText
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showCustomInput)
    }
}
