//
//  PlanGoalBadge.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import SwiftUI

struct PlanGoalBadge: View {

    let displayText: String

    private let iconColor = Color(hex: "E86A75")

    var body: some View {
        HStack(spacing: 10) {
            // Pink circle with target icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(displayText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.gymBroNeutral900)
        }
    }
}

#Preview {
    PlanGoalBadge(displayText: "Build Muscle \u{2022} Intermediate")
        .padding()
}
