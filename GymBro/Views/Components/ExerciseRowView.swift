//
//  ExerciseRowView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-23.
//

import SwiftUI

struct ExerciseRowView: View {
    let name: String
    let sets: String
    let step: Int
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

                Text("STEP \(step)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "A1A1A1"))
                    .textCase(.uppercase)
            }

            Spacer()

            // Sets badge
            Text(sets)
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
        .padding(.vertical, 4)
    }
}
