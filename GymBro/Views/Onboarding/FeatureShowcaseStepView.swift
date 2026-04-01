//
//  FeatureShowcaseStepView.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import SwiftUI

/// Generic view for feature showcase onboarding steps
struct FeatureShowcaseStepView: View {
    let content: FeatureShowcaseContent

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(icon: content.iconName, title: content.title)

            PhoneMockupView(imageName: content.imageName)

            Text(content.description)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gymBroNeutral600)
                .tracking(-0.31)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 16) {
                ForEach(Array(content.features.enumerated()), id: \.offset) { _, feature in
                    FeatureShowcaseCard(
                        icon: feature.icon,
                        title: feature.title,
                        subtitle: feature.subtitle
                    )
                }
            }
        }
    }
}

#Preview("Track Every Rep") {
    ScrollView {
        FeatureShowcaseStepView(content: .trackEveryRep)
            .padding(24)
    }
    .background(Color.gymBroBackground)
}

#Preview("Personalized Plans") {
    ScrollView {
        FeatureShowcaseStepView(content: .personalizedPlans)
            .padding(24)
    }
    .background(Color.gymBroBackground)
}

#Preview("AI Coach") {
    ScrollView {
        FeatureShowcaseStepView(content: .aiCoach)
            .padding(24)
    }
    .background(Color.gymBroBackground)
}

#Preview("Train Together") {
    ScrollView {
        FeatureShowcaseStepView(content: .trainTogether)
            .padding(24)
    }
    .background(Color.gymBroBackground)
}
