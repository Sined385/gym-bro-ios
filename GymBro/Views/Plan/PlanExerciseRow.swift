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

    var body: some View {
        HStack(spacing: 14) {
            // Colored accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 6, height: 28)

            // Exercise info
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Text(muscleGroup)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "A1A1A1"))
            }

            Spacer()

            // Sets badge
            Text(setsDisplay)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "525252"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gymBroNeutral100, lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.04),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    VStack(spacing: 8) {
        PlanExerciseRow(name: "Bench Press", muscleGroup: "Chest", setsDisplay: "4 \u{00D7} 8", accentColor: Color(hex: "E86A75"))
        PlanExerciseRow(name: "Barbell Row", muscleGroup: "Back", setsDisplay: "4 \u{00D7} 8", accentColor: Color(hex: "30C08D"))
    }
    .padding()
}
