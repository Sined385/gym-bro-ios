//
//  LiveComparisonCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

struct LiveComparisonCard: View {
    let exercise: ActiveSessionExercise
    let lastSets: [PreviousSet]

    var body: some View {
        let prevSets = lastSets
        let currentSets = exercise.sets.filter { $0.isCompleted }

        let totalVolume = currentSets.reduce(0.0) { $0 + (($1.weight ?? 0) * Double($1.reps ?? 0)) }
        let avgWeight = currentSets.isEmpty ? 0.0 : currentSets.reduce(0.0) { $0 + ($1.weight ?? 0) } / Double(currentSets.count)
        let totalReps = currentSets.reduce(0) { $0 + ($1.reps ?? 0) }
        let setCount = currentSets.count

        let hasPrevData = !prevSets.isEmpty
        let prevVolume = prevSets.reduce(0.0) { $0 + (($1.weight ?? 0) * Double($1.reps)) }
        let prevAvgWeight = prevSets.isEmpty ? 0.0 : prevSets.reduce(0.0) { $0 + ($1.weight ?? 0) } / Double(prevSets.count)
        let prevTotalReps = prevSets.reduce(0) { $0 + $1.reps }
        let prevSetCount = prevSets.count

        return VStack(spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gymBroNeutral400)
                Text("VS LAST SESSION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(.gymBroNeutral400)
                Spacer()
            }

            // Stats grid
            let hasToday = !currentSets.isEmpty
            HStack(spacing: 12) {
                comparisonStat(
                    label: "VOLUME",
                    value: hasToday ? "\(Int(totalVolume))kg" : "--",
                    todayValue: hasToday ? Int(totalVolume) : nil,
                    prevValue: hasPrevData ? Int(prevVolume) : nil
                )
                comparisonStat(
                    label: "AVG WT",
                    value: hasToday ? "\(Int(avgWeight))kg" : "--",
                    todayValue: hasToday ? Int(avgWeight) : nil,
                    prevValue: hasPrevData ? Int(prevAvgWeight) : nil
                )
                comparisonStat(
                    label: "REPS",
                    value: hasToday ? "\(totalReps)" : "--",
                    todayValue: hasToday ? totalReps : nil,
                    prevValue: hasPrevData ? prevTotalReps : nil
                )
                comparisonStat(
                    label: "SETS",
                    value: hasToday ? "\(setCount)" : "--",
                    todayValue: hasToday ? setCount : nil,
                    prevValue: hasPrevData ? prevSetCount : nil
                )
            }
        }
        .padding(16)
        .background(Color.gymBroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 10, y: 2)
        .overlay(alignment: .topTrailing) {
            // Decorative layered icon
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 48))
                .foregroundColor(.gymBroNeutral200.opacity(0.4))
                .padding(.top, -8)
                .padding(.trailing, 8)
        }
    }

    private func comparisonStat(label: String, value: String, todayValue: Int?, prevValue: Int?) -> some View {
        let delta: Int? = {
            guard let today = todayValue, let prev = prevValue else { return nil }
            return today - prev
        }()

        return VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.gymBroNeutral400)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(todayValue != nil ? .gymBroNeutral900 : .gymBroNeutral400)

            if let delta = delta {
                let isUp = delta > 0
                let isDown = delta < 0
                let arrow = isUp ? "arrow.up.right" : (isDown ? "arrow.down.right" : "equal")
                let color: Color = isUp ? Color(hex: "30C08D") : (isDown ? .gymBroPrimary : .gymBroNeutral400)

                HStack(spacing: 3) {
                    Image(systemName: arrow)
                        .font(.system(size: 10, weight: .bold))
                    Text(delta == 0 ? "0" : "\(abs(delta))")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gymBroNeutral400)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gymBroNeutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
