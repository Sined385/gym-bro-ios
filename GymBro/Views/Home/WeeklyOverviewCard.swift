//
//  WeeklyOverviewCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-24.
//

import SwiftUI

struct WeeklyOverviewCard: View {

    // MARK: - Properties

    let overview: String
    let weekWorkouts: Int
    let weekVolumeKg: Double?
    let weekAvgDuration: Int?
    let weekCalories: Int?
    let avgWorkouts: Double?
    let avgVolumeKg: Double?
    let avgDuration: Int?
    let avgCalories: Int?

    // MARK: - Constants

    private let accentColor = Color(hex: "7A82F6")
    private let labelColor = Color(hex: "A1A1A1")
    private let mutedColor = Color(hex: "737373")
    private let borderColor = Color.gymBroNeutral100

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.10))
                        .frame(width: 28, height: 28)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                Text("WEEKLY OVERVIEW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(labelColor)
            }

            // AI overview text
            Text(overview)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gymBroNeutral900)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Comparison grid
            if avgWorkouts != nil {
                comparisonGrid
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.03),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    // MARK: - Comparison Grid

    private var comparisonGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                statCell(
                    label: "Workouts",
                    value: "\(weekWorkouts)",
                    avg: avgWorkouts.map { String(format: "%.1f", $0) },
                    isUp: avgWorkouts.map { Double(weekWorkouts) > $0 }
                )
                statCell(
                    label: "Volume",
                    value: formatVolume(weekVolumeKg),
                    avg: avgVolumeKg.map { formatVolume($0) },
                    isUp: (weekVolumeKg != nil && avgVolumeKg != nil) ? weekVolumeKg! > avgVolumeKg! : nil
                )
            }
            HStack(spacing: 8) {
                statCell(
                    label: "Duration",
                    value: weekAvgDuration.map { "\($0) min" } ?? "--",
                    avg: avgDuration.map { "\($0) min" },
                    isUp: (weekAvgDuration != nil && avgDuration != nil) ? weekAvgDuration! > avgDuration! : nil
                )
                statCell(
                    label: "Calories",
                    value: weekCalories.map { formatNumber($0) } ?? "--",
                    avg: avgCalories.map { formatNumber($0) },
                    isUp: (weekCalories != nil && avgCalories != nil) ? weekCalories! > avgCalories! : nil
                )
            }
        }
    }

    private func statCell(label: String, value: String, avg: String?, isUp: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.4)
                .foregroundColor(labelColor)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                if let isUp, let avg {
                    HStack(spacing: 2) {
                        Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("avg \(avg)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isUp ? Color(hex: "30C08D") : Color(hex: "E86A75"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(hex: "F8F9FA"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Formatting

    private func formatVolume(_ kg: Double?) -> String {
        guard let kg else { return "--" }
        let rounded = Int(kg.rounded())
        if rounded >= 1000 {
            return String(format: "%.1fk", Double(rounded) / 1000)
        }
        return formatNumber(rounded)
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        WeeklyOverviewCard(
            overview: "Volume up 18% this week \u{2014} you're building momentum. Consistency is solid at 3 sessions. Consider pushing duration closer to your 50-min target.",
            weekWorkouts: 3,
            weekVolumeKg: 8420,
            weekAvgDuration: 48,
            weekCalories: 1850,
            avgWorkouts: 2.3,
            avgVolumeKg: 7100,
            avgDuration: 52,
            avgCalories: 1620
        )
        .padding(.horizontal, 20)
    }
    .background(Color.gymBroBackground)
}
