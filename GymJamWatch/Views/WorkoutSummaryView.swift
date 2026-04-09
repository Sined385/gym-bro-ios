//
//  WorkoutSummaryView.swift
//  GymJamWatch
//
//  Post-workout summary on Watch.
//

import SwiftUI

struct WorkoutSummaryView: View {

    let summary: WatchWorkoutSummary
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 32))
                    .foregroundColor(WatchColors.primary)

                Text("Workout Complete")
                    .font(WatchTypography.sectionTitle)
                    .foregroundColor(.white)

                // Stats grid
                VStack(spacing: 8) {
                    StatRow(icon: "clock.fill", label: "Duration", value: formatDuration(summary.totalDurationSeconds))
                    StatRow(icon: "flame.fill", label: "Calories", value: "\(Int(summary.activeCalories)) kcal")

                    if let avgHR = summary.averageHeartRate {
                        StatRow(icon: "heart.fill", label: "Avg HR", value: "\(Int(avgHR)) bpm")
                    }
                    if let maxHR = summary.maxHeartRate {
                        StatRow(icon: "heart.fill", label: "Max HR", value: "\(Int(maxHR)) bpm")
                    }
                }
                .padding(10)
                .background(WatchColors.cardBackground)
                .cornerRadius(12)

                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(WatchPrimaryButtonStyle())
            }
            .padding(.horizontal, 8)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m) min"
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(WatchColors.primary)
                .frame(width: 20)

            Text(label)
                .font(WatchTypography.caption)
                .foregroundColor(WatchColors.textSecondary)

            Spacer()

            Text(value)
                .font(WatchTypography.body)
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }
}
