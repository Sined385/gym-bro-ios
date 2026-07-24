//
//  EquipmentView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine

/// Onboarding screen - Available equipment selection
struct EquipmentView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            // Header
            StepHeader(
                icon: "dumbbell.fill",
                title: String(localized: "Available equipment?")
            )

            // Equipment selection cards
            VStack(spacing: 12) {
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    SelectionCard(
                        title: equipment.displayName,
                        isSelected: viewModel.onboardingData.availableEquipment == equipment,
                        onTap: {
                            viewModel.selectEquipment(equipment)
                        }
                    )
                }
            }
        }
    }
}
