//
//  SessionMiniPlayerBar.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import SwiftUI

struct SessionMiniPlayerBar: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager

    private let purpleAccent = Color(hex: "7A82F6")

    var body: some View {
        HStack(spacing: 14) {
            // Icon — changes when resting
            ZStack {
                Circle()
                    .fill(sessionManager.isResting ? purpleAccent.opacity(0.15) : Color.gymBroPrimary.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: sessionManager.isResting ? "stopwatch.fill" : "dumbbell.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(sessionManager.isResting ? purpleAccent : .gymBroPrimary)
            }

            // Session info
            VStack(alignment: .leading, spacing: 2) {
                if sessionManager.isResting {
                    Text("Rest — \(sessionManager.formattedRestTime)")
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundColor(purpleAccent)
                        .lineLimit(1)
                } else {
                    Text(sessionManager.sessionTitle ?? "Workout")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                        .lineLimit(1)
                }

                Text(sessionManager.formattedTime)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(.gymBroNeutral400)
            }

            Spacer()

            if sessionManager.isResting {
                // Skip rest button
                Button {
                    sessionManager.skipRestTimer()
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(purpleAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(purpleAccent.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gymBroNeutral400)
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
        .onTapGesture {
            sessionManager.expand()
        }
    }
}
