//
//  RestTimerView.swift
//  GymJamWatch
//
//  Full-screen rest countdown with progress ring and haptics.
//

import SwiftUI

struct RestTimerView: View {

    @EnvironmentObject var restTimerViewModel: WatchRestTimerViewModel

    var body: some View {
        if restTimerViewModel.isFinished {
            completedView
        } else if restTimerViewModel.isActive {
            activeTimerView
        } else {
            inactiveView
        }
    }

    // MARK: - Active Timer

    private var activeTimerView: some View {
        VStack(spacing: 8) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: 1 - restTimerViewModel.progress)
                    .stroke(
                        WatchColors.purple,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: restTimerViewModel.progress)

                VStack(spacing: 2) {
                    Text(restTimerViewModel.formattedTime)
                        .font(WatchTypography.displayLarge)
                        .foregroundColor(WatchColors.purple)
                        .monospacedDigit()

                    Text("REST")
                        .font(WatchTypography.micro)
                        .foregroundColor(WatchColors.textSecondary)
                }
            }
            .frame(width: 100, height: 100)

            // Action buttons
            HStack(spacing: 8) {
                Button("Skip") {
                    WatchHaptics.digitalCrownTick()
                    restTimerViewModel.skip()
                }
                .buttonStyle(WatchOutlineButtonStyle())

                Button("+30s") {
                    WatchHaptics.digitalCrownTick()
                    restTimerViewModel.extend30()
                }
                .buttonStyle(WatchOutlineButtonStyle())
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)

            Text("Rest Complete!")
                .font(WatchTypography.sectionTitle)
                .foregroundColor(.green)

            Text("Time for next set")
                .font(WatchTypography.caption)
                .foregroundColor(WatchColors.textSecondary)
        }
    }

    // MARK: - Inactive

    private var inactiveView: some View {
        VStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 30))
                .foregroundColor(WatchColors.textSecondary)

            Text("Rest timer will\nappear here")
                .font(WatchTypography.caption)
                .foregroundColor(WatchColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
