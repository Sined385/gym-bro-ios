//
//  RestDayCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import SwiftUI

struct RestDayCard: View {

    // MARK: - Properties

    var weekWorkoutsCompleted: Int
    var weekWorkoutsTotal: Int
    var weekVolumeKg: Double?
    var weekStreak: Int?
    var personalRecords: [String]
    var restingHeartRate: Double?
    var latestWeightKg: Double?
    var todayActiveEnergy: Double?
    var latestBodyFat: Double?
    var latestLeanBodyMass: Double?
    var todayStepCount: Double?
    var lastNightSleep: Double?
    var latestHRV: Double?
    var latestVO2Max: Double?
    var todayWalkingDistance: Double?
    var weekAvgDurationMinutes: Int?
    var weekTotalCalories: Int?

    // MARK: - Constants

    private let purpleGradientStart = Color(hex: "7A82F6")
    private let purpleGradientEnd = Color(hex: "5A61D6")
    private let cardBackground = Color.white
    private let metadataColor = Color(hex: "737373")

    // MARK: - Static Data

    // MARK: - Computed

    private var statsEntries: [(label: String, value: String, icon: String)] {
        var entries: [(label: String, value: String, icon: String)] = []
        if let weight = latestWeightKg {
            entries.append(("Body Weight", String(format: "%.1f kg", weight), "scalemass.fill"))
        }
        if let hr = restingHeartRate {
            entries.append(("Resting HR", "\(Int(hr)) bpm", "heart.fill"))
        }
        if let hrv = latestHRV {
            entries.append(("HRV", "\(Int(hrv)) ms", "waveform.path.ecg"))
        }
        if let sleep = lastNightSleep {
            let hours = Int(sleep)
            let mins = Int((sleep - Double(hours)) * 60)
            entries.append(("Sleep", "\(hours)h \(mins)m", "bed.double.fill"))
        }
        if let energy = todayActiveEnergy {
            entries.append(("Active Energy", "\(Int(energy)) kcal", "flame.fill"))
        }
        if let steps = todayStepCount {
            entries.append(("Steps", Self.formatNumber(steps), "figure.walk"))
        }
        if let distance = todayWalkingDistance {
            entries.append(("Distance", String(format: "%.1f km", distance), "location.fill"))
        }
        if let vo2 = latestVO2Max {
            entries.append(("VO2 Max", String(format: "%.1f", vo2), "lungs.fill"))
        }
        if let bf = latestBodyFat {
            entries.append(("Body Fat", String(format: "%.1f%%", bf), "percent"))
        }
        if let lbm = latestLeanBodyMass {
            entries.append(("Lean Mass", String(format: "%.1f kg", lbm), "figure.arms.open"))
        }
        if let volume = weekVolumeKg, volume > 0 {
            entries.append(("Week Volume", Self.formatVolume(volume), "figure.strengthtraining.traditional"))
        }
        if let calories = weekTotalCalories, calories > 0 {
            entries.append(("Week Calories", Self.formatNumber(Double(calories)) + " kcal", "bolt.fill"))
        }
        if let avgDur = weekAvgDurationMinutes, avgDur > 0 {
            entries.append(("Avg Duration", "\(avgDur) min", "clock.fill"))
        }
        return entries
    }

    private static func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
    }

    private static func formatVolume(_ value: Double) -> String {
        let intValue = Int(value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return (formatter.string(from: NSNumber(value: intValue)) ?? "\(intValue)") + " kg"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            Text("Rest & Recovery")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.44)
                .foregroundColor(.gymBroNeutral900)

            // Hero card
            heroCard

            // Your Stats grid (only if we have data)
            if !statsEntries.isEmpty {
                statGrid
            }

            // Week progress
            weekProgressCard
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)

            Text("Well Deserved Rest")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.44)
                .foregroundColor(.white)

            Text("Your body grows stronger during recovery. Take it easy today and come back refreshed.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [purpleGradientStart, purpleGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(
            color: purpleGradientStart.opacity(0.3),
            radius: 12,
            x: 0,
            y: 8
        )
    }

    // MARK: - Stat Grid

    private var statGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(statsEntries, id: \.label) { stat in
                    HStack(spacing: 10) {
                        Image(systemName: stat.icon)
                            .font(.system(size: 16))
                            .foregroundColor(purpleGradientStart)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.value)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.gymBroNeutral900)
                            Text(stat.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(metadataColor)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gymBroNeutral100, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Week Progress

    private var weekProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Week's Progress")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()



            }

            HStack(spacing: 0) {
                // Workouts
                VStack(spacing: 4) {
                    Text("\(weekWorkoutsCompleted)/\(weekWorkoutsTotal)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("Workouts")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 40)

                // PBs
                VStack(spacing: 4) {
                    Text("\(personalRecords.count)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("PBs")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 40)

                // Volume
                VStack(spacing: 4) {
                    Text(weekVolumeKg.map { Self.formatVolume($0).replacingOccurrences(of: " kg", with: "") } ?? "—")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("kg")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "2D3240"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    ScrollView {
        RestDayCard(
            weekWorkoutsCompleted: 3,
            weekWorkoutsTotal: 5,
            weekVolumeKg: 12450,
            weekStreak: 3,
            personalRecords: ["Bench Press", "Squat"],
            restingHeartRate: 62,
            latestWeightKg: 78.5,
            todayActiveEnergy: 320,
            latestBodyFat: 15.2,
            latestLeanBodyMass: 66.6,
            todayStepCount: 8432,
            lastNightSleep: 7.5,
            latestHRV: 45,
            latestVO2Max: 42.3,
            todayWalkingDistance: 5.2,
            weekAvgDurationMinutes: 48,
            weekTotalCalories: 1850
        )
        .padding(.horizontal, 20)
    }
    .background(Color.gymBroBackground)
}
