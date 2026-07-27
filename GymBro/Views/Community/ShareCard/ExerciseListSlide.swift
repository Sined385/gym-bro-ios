//
//  ExerciseListSlide.swift
//  GymBro
//
//  Carousel slide #3: a full-height vertical list of every exercise in the
//  workout. Mirrors the card's row design but with no truncation cap.
//

import SwiftUI

struct ExerciseListSlide: View {
    let workout: WorkoutSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.gymBroPrimary)
                Text("EXERCISES · \(workout.exercises.count)")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.7)
                    .foregroundColor(.gymBroPrimary)
            }
            .padding(.top, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { idx, ex in
                        row(ex, index: idx)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }

    private func row(_ ex: WorkoutSnapshotExercise, index: Int) -> some View {
        let accent = Color(hex: ex.accentColorHex)
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(accent.opacity(0.14))
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(accent)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(localizedExerciseName(ex.name, externalId: ex.externalId))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.gymBroNeutral900)
                        .lineLimit(1)
                }
                if let mg = ex.muscleGroup, !mg.isEmpty {
                    // Cardio shows time + distance in `bestSetLine`, so the
                    // subtitle is just the muscle group (no "N SETS").
                    Text(ex.isCardio ? mg.uppercased() : "\(mg.uppercased()) · \(ex.setChips.count) SETS")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.4)
                        .foregroundColor(.gymBroTextSecondary)
                }
            }

            Spacer(minLength: 4)

            Text(ex.bestSetLine)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.gymBroNeutral900)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.gymBroNeutral100.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
