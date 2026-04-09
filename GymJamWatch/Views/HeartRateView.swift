//
//  HeartRateView.swift
//  GymJamWatch
//
//  Live BPM display with zone indicator.
//

import SwiftUI

struct HeartRateView: View {

    @EnvironmentObject var sessionViewModel: WatchSessionViewModel

    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 10) {
            // Heart icon with pulse animation
            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundColor(WatchColors.primary)
                .scaleEffect(heartScale)
                .onChange(of: sessionViewModel.currentHeartRate) { _, _ in
                    pulseAnimation()
                }

            // BPM display
            if sessionViewModel.currentHeartRate > 0 {
                Text("\(Int(sessionViewModel.currentHeartRate))")
                    .font(WatchTypography.displayLarge)
                    .foregroundColor(WatchColors.primary)
                    .monospacedDigit()

                Text("BPM")
                    .font(WatchTypography.caption)
                    .foregroundColor(WatchColors.textSecondary)

                // HR Zone
                let zone = HeartRateZone.zone(for: sessionViewModel.currentHeartRate)
                Text(zone.rawValue)
                    .font(WatchTypography.body)
                    .foregroundColor(zone.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(zone.color.opacity(0.2))
                    .cornerRadius(8)
            } else {
                Text("—")
                    .font(WatchTypography.displayLarge)
                    .foregroundColor(WatchColors.textSecondary)

                Text("BPM")
                    .font(WatchTypography.caption)
                    .foregroundColor(WatchColors.textSecondary)

                Text("Measuring...")
                    .font(WatchTypography.caption)
                    .foregroundColor(WatchColors.textSecondary)
            }

            Spacer()

            // Average & Max
            if sessionViewModel.averageHeartRate > 0 {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("AVG")
                            .font(WatchTypography.micro)
                            .foregroundColor(WatchColors.textSecondary)
                        Text("\(Int(sessionViewModel.averageHeartRate))")
                            .font(WatchTypography.body)
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }

                    VStack(spacing: 2) {
                        Text("MAX")
                            .font(WatchTypography.micro)
                            .foregroundColor(WatchColors.textSecondary)
                        Text("\(Int(sessionViewModel.maxHeartRate))")
                            .font(WatchTypography.body)
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func pulseAnimation() {
        withAnimation(.easeInOut(duration: 0.15)) {
            heartScale = 1.2
        }
        withAnimation(.easeInOut(duration: 0.15).delay(0.15)) {
            heartScale = 1.0
        }
    }
}
