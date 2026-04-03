//
//  PlanExerciseRow.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import SwiftUI

struct PlanExerciseRow: View {

    let name: String
    let muscleGroup: String
    let setsDisplay: String
    let accentColor: Color
    var imageUrl: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            // Colored accent bar
            RoundedRectangle(cornerRadius: 100)
                .fill(accentColor)
                .frame(width: 6, height: 56)

            // Exercise image
            exerciseImage

            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .lineLimit(1)
                    .tracking(-0.3)

                HStack(spacing: 6) {
                    if !muscleGroup.isEmpty {
                        Text(muscleGroup.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.6)
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if !setsDisplay.isEmpty {
                        Text(setsDisplay.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.6)
                            .foregroundColor(Color(hex: "737373"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(Color(hex: "F5F5F5"))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 1)
        .frame(minHeight: 72)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var exerciseImage: some View {
        if let imageUrl, let url = URL(string: imageUrl) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                exercisePlaceholder
            } failure: {
                exercisePlaceholder
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            exercisePlaceholder
        }
    }

    private var exercisePlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(hex: "F5F5F5"))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "D4D4D4"))
            )
    }
}

#Preview {
    VStack(spacing: 8) {
        PlanExerciseRow(name: "Bench Press", muscleGroup: "Chest", setsDisplay: "4 \u{00D7} 8", accentColor: Color(hex: "E86A75"))
        PlanExerciseRow(name: "Barbell Row", muscleGroup: "Back", setsDisplay: "4 \u{00D7} 8", accentColor: Color(hex: "30C08D"))
    }
    .padding()
}
