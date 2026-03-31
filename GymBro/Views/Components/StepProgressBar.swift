//
//  StepProgressBar.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI

/// Animated progress indicator with gradient fill
struct StepProgressBar: View {
    let progress: Double // 0.0 to 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.gymBroNeutral200.opacity(0.6))
                    .frame(height: 10)

                // Fill
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.gymBroPrimaryGradient)
                    .frame(width: geometry.size.width * max(0, min(1, progress)), height: 10)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
            }
            // Inner shadow overlay
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    .offset(y: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 999))
            )
        }
        .frame(height: 10)
    }
}

#Preview {
    VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
            Text("0%")
                .font(.gymBroCaption)
            StepProgressBar(progress: 0.0)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("25%")
                .font(.gymBroCaption)
            StepProgressBar(progress: 0.25)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("50%")
                .font(.gymBroCaption)
            StepProgressBar(progress: 0.5)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("75%")
                .font(.gymBroCaption)
            StepProgressBar(progress: 0.75)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("100%")
                .font(.gymBroCaption)
            StepProgressBar(progress: 1.0)
        }
    }
    .padding()
    .background(Color.gymBroBackground)
}
