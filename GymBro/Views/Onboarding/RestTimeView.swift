//
//  RestTimeView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-26.
//

import SwiftUI
import Combine

/// Onboarding screen - Rest time between sets selection
struct RestTimeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "timer",
                title: "Preferred rest between sets?"
            )

            RestTimeStepper(
                seconds: Binding(
                    get: { viewModel.onboardingData.preferredRestTime?.rawValue ?? 90 },
                    set: { newValue in
                        if let restTime = RestTime(rawValue: newValue) {
                            viewModel.selectRestTime(restTime)
                        }
                    }
                )
            )
        }
        .onAppear {
            if viewModel.onboardingData.preferredRestTime == nil {
                viewModel.selectRestTime(.ninety)
            }
        }
    }
}

// MARK: - Reusable Rest Time Stepper

/// A stepper control with - and + buttons around a time display.
/// Increments/decrements by 30 seconds, clamped to 30s–300s.
struct RestTimeStepper: View {
    @Binding var seconds: Int

    private let step = 30
    private let minSeconds = 30
    private let maxSeconds = 300

    private var canDecrement: Bool { seconds > minSeconds }
    private var canIncrement: Bool { seconds < maxSeconds }

    var body: some View {
        HStack(spacing: 20) {
            // Minus button
            Button {
                if canDecrement { seconds -= step }
            } label: {
                ZStack {
                    Circle()
                        .fill(canDecrement ? Color.gymBroPrimary : Color(hex: "E5E5E5"))
                        .frame(width: 52, height: 52)

                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(!canDecrement)

            // Time display
            VStack(spacing: 4) {
                Text(formatTime(seconds))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: seconds)

                Text("minutes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gymBroTextSecondary)
            }
            .frame(minWidth: 120)

            // Plus button
            Button {
                if canIncrement { seconds += step }
            } label: {
                ZStack {
                    Circle()
                        .fill(canIncrement ? Color.gymBroPrimary : Color(hex: "E5E5E5"))
                        .frame(width: 52, height: 52)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(!canIncrement)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        if s == 0 {
            return "\(m):00"
        }
        return "\(m):\(String(format: "%02d", s))"
    }
}
