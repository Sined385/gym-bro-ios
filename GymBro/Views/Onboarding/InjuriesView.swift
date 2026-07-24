//
//  InjuriesView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine

/// Onboarding screen - Injuries selection (multi-select with custom input)
struct InjuriesView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showCustomInput = false

    var body: some View {
        VStack(spacing: 32) {
            // Header
            StepHeader(
                icon: "exclamationmark.triangle.fill",
                title: String(localized: "Any current injuries?")
            )

            VStack(spacing: 12) {
                // Standard injury selection cards
                ForEach(InjuryType.standardCases, id: \.self) { injury in
                    SelectionCard(
                        title: injury.displayName,
                        isSelected: viewModel.onboardingData.injuries.contains(injury),
                        onTap: {
                            viewModel.toggleInjury(injury)
                        }
                    )
                }

                // Custom injury option
                SelectionCard(
                    title: String(localized: "Other (Custom)"),
                    isSelected: showCustomInput,
                    showCheckmark: true,
                    onTap: {
                        showCustomInput.toggle()
                    }
                )

                // Custom input field
                if showCustomInput {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            CustomTextField(
                                placeholder: "Please specify...",
                                text: $viewModel.customInputText
                            )

                            Button(action: {
                                viewModel.addCustomInjury()
                                viewModel.customInputText = ""
                            }) {
                                Text("Add")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .frame(height: 60)
                                    .background(
                                        viewModel.customInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            ? Color.gymBroTextSecondary
                                            : Color.gymBroPrimary
                                    )
                                    .cornerRadius(20)
                            }
                            .disabled(viewModel.customInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Display selected custom injuries as chips
                if !customInjuries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom injuries:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                            .padding(.top, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(customInjuries, id: \.self) { injury in
                                    InjuryChip(
                                        title: injury.displayName,
                                        onRemove: {
                                            withAnimation {
                                                viewModel.toggleInjury(injury)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCustomInput)
    }

    // Helper to get custom injuries
    private var customInjuries: [InjuryType] {
        viewModel.onboardingData.injuries.filter { injury in
            if case .custom = injury {
                return true
            }
            return false
        }
    }
}

/// Chip component for displaying selected custom injuries
struct InjuryChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.gymBroTextPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gymBroTextSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gymBroNeutral100)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gymBroBorderLight, lineWidth: 1)
        )
    }
}
