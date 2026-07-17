//
//  OnboardingContainerView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine

/// Main coordinator container for the onboarding flow
struct OnboardingContainerView: View {
    @StateObject var viewModel: OnboardingViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.dependencies) var dependencies

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.gymBroBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress section
                    progressSection
                        .padding(.top, 48)

                    // Current step view
                    currentStepView
                        .frame(maxHeight: .infinity)

                    // Submission/network errors — without this, a failed
                    // "Build My Plan" tap is completely silent.
                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                    }

                    // Footer with navigation buttons
                    footerSection
                }
            }
            .navigationBarHidden(true)
        }
        .analyticsScreen("Onboarding")
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(progressLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "737373"))
                    .tracking(0.6)
                    .textCase(.uppercase)

                Spacer()

                Text(progressPercentage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroPrimary)
                    .tracking(-0.31)
            }

            StepProgressBar(progress: viewModel.calculateProgress())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private var progressLabel: String {
        let stepNumber = viewModel.currentStep.rawValue - 1 // auth=0, rest are 1-based visible steps
        let totalVisible = OnboardingStep.allCases.count - 1 // exclude authentication
        return "Step \(stepNumber) of \(totalVisible)"
    }

    private var progressPercentage: String {
        let pct = Int(viewModel.calculateProgress() * 100)
        return "\(pct)%"
    }

    // MARK: - Current Step View

    @ViewBuilder
    private var currentStepView: some View {
        ScrollView {
            VStack(spacing: 32) {
                switch viewModel.currentStep {
                case .authentication:
                    AuthenticationView(authViewModel: authViewModel)

                case .showcaseTrack:
                    FeatureShowcaseStepView(content: .trackEveryRep)

                case .showcasePlans:
                    FeatureShowcaseStepView(content: .personalizedPlans)

                case .showcaseCoach:
                    FeatureShowcaseStepView(content: .aiCoach)

                case .showcaseCommunity:
                    FeatureShowcaseStepView(content: .trainTogether)

                case .primaryGoal:
                    PrimaryGoalView(viewModel: viewModel)

                case .primarySport:
                    PrimarySportView(viewModel: viewModel)

                case .experienceLevel:
                    ExperienceLevelView(viewModel: viewModel)

                case .bodyMetrics:
                    BodyMetricsView(viewModel: viewModel)

                case .trainingFrequency:
                    TrainingFrequencyView(viewModel: viewModel)

                case .workoutDuration:
                    WorkoutDurationView(viewModel: viewModel)

                case .restTime:
                    RestTimeView(viewModel: viewModel)

                case .equipment:
                    EquipmentView(viewModel: viewModel)

                case .injuries:
                    InjuriesView(viewModel: viewModel)

                case .completeProfile:
                    CompleteProfileView(viewModel: viewModel)

                case .aboutYou:
                    AboutYouView(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 24)
            // Add bottom padding for footer
            .padding(.bottom, 120)
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 12) {
            // Back button (show if not first step)
            if !isFirstStep {
                Button(action: {
                    viewModel.previousStep()
                }) {
                    Text("Back")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gymBroPrimary)
                        .tracking(-0.31)
                        .frame(width: 90, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gymBroPrimary, lineWidth: 2)
                        )
                }
            }

            // Continue/Submit button
            GradientButton(
                title: continueButtonTitle,
                isLoading: viewModel.isSubmitting,
                isDisabled: !viewModel.canContinue,
                cornerRadius: 16,
                action: handleContinue
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(.red)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
        .padding(.horizontal, 24)
        .transition(.opacity)
    }

    // MARK: - Helpers

    private var isFirstStep: Bool {
        return viewModel.currentStep == .showcaseTrack
    }

    private var continueButtonTitle: String {
        // About You is the new final step — it owns the "Build My Plan" CTA
        // and the submit trigger. CompleteProfile is now second-to-last with
        // a regular Continue button.
        if viewModel.currentStep == .aboutYou {
            return "Build My Plan"
        } else {
            return "Continue"
        }
    }

    private func handleContinue() {
        if viewModel.currentStep == .aboutYou {
            // Final step - submit onboarding
            Task {
                do {
                    try await viewModel.submitOnboarding()
                    // Update auth state
                    await authViewModel.checkOnboardingStatus()
                    // Navigate to home via coordinator
                    coordinator.handleOnboardingCompletion()
                } catch {
                    // Error is already set in viewModel
                    print("Onboarding submission failed: \(error)")
                }
            }
        } else {
            // Move to next step
            viewModel.nextStep()
        }
    }
}
