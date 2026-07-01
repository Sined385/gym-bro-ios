//
//  RestTimerBar.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

struct RestTimerBar: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    let remaining: Int
    /// Tapping the bar (not the +30s/Skip buttons) jumps back to the exercise
    /// whose set was logged most recently, so you can log the next set.
    var onTapBar: (() -> Void)? = nil

    private let purpleAccent = Color(hex: "7A82F6")

    var body: some View {
        let minutes = remaining / 60
        let seconds = remaining % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)

        return HStack {
            // Timer icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("REST TIME")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.8))
                Text(timeString)
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }

            Spacer()

            // +30s button
            Button {
                sessionManager.addRestTime(30)
            } label: {
                Text("+30s")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Skip button
            Button {
                sessionManager.skipRestTimer()
            } label: {
                Text("Skip")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(purpleAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [purpleAccent, Color(hex: "6366F1")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: purpleAccent.opacity(0.4), radius: 16, y: 8)
        // Whole-bar tap → jump to the last-executed exercise. The +30s/Skip
        // Buttons sit above this and consume their own taps first.
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture { onTapBar?() }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}
