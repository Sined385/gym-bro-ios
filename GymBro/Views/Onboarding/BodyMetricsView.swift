//
//  BodyMetricsView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-25.
//

import SwiftUI
import Combine

/// Onboarding screen - Body metrics (weight, height, sex) with HealthKit prefill
struct BodyMetricsView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            // Header
            StepHeader(
                icon: "figure.arms.open",
                title: "About you"
            )

            // HealthKit status badge
            if viewModel.healthKitLoaded {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "30C08D"))

                    Text("Imported from Health")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "30C08D"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: "30C08D").opacity(0.08))
                .cornerRadius(16)
            }

            // Weight & Height inputs
            VStack(spacing: 12) {
                // Weight
                VStack(alignment: .leading, spacing: 8) {
                    Text("WEIGHT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "737373"))
                        .tracking(0.6)

                    HStack(spacing: 0) {
                        TextField("70", text: $viewModel.weightText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gymBroNeutral900)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.weightText) { _, newValue in
                                viewModel.updateWeight(newValue)
                            }

                        Text("kg")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gymBroNeutral400)
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 60)
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                viewModel.onboardingData.weightKg != nil
                                    ? Color.gymBroPrimary
                                    : Color.gymBroNeutral100,
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
                }

                // Height
                VStack(alignment: .leading, spacing: 8) {
                    Text("HEIGHT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "737373"))
                        .tracking(0.6)

                    HStack(spacing: 0) {
                        TextField("175", text: $viewModel.heightText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gymBroNeutral900)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.heightText) { _, newValue in
                                viewModel.updateHeight(newValue)
                            }

                        Text("cm")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gymBroNeutral400)
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 60)
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                viewModel.onboardingData.heightCm != nil
                                    ? Color.gymBroPrimary
                                    : Color.gymBroNeutral100,
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
                }
            }

            // Sex selection
            VStack(alignment: .leading, spacing: 12) {
                Text("SEX")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "737373"))
                    .tracking(0.6)

                HStack(spacing: 12) {
                    ForEach(BiologicalSex.allCases, id: \.self) { sex in
                        sexCard(sex)
                    }
                }
            }
        }
        .task {
            await viewModel.loadFromHealthKit()
        }
    }

    // MARK: - Sex Card

    private func sexCard(_ sex: BiologicalSex) -> some View {
        let isSelected = viewModel.onboardingData.biologicalSex == sex

        return Button {
            viewModel.selectBiologicalSex(sex)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: sex.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .gymBroPrimary : .gymBroNeutral400)

                Text(sex.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .gymBroPrimary : .gymBroNeutral600)
                    .tracking(-0.31)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.gymBroPrimary : Color.gymBroNeutral100,
                        lineWidth: 2
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
