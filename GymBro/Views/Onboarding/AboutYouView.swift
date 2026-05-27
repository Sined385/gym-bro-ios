//
//  AboutYouView.swift
//  GymBro
//
//  Final onboarding step — free-form context the AI uses for every
//  plan and coach reply. Optional; user can finish onboarding with
//  an empty field.
//

import SwiftUI

struct AboutYouView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "note.text",
                title: "Anything else?"
            )

            AboutYouField(text: $viewModel.onboardingData.aiCoachContext)
        }
    }
}
