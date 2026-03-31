//
//  StartSessionButton.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-13.
//

import SwiftUI

struct StartSessionButton: View {

    // MARK: - Constants

    private let buttonBackground = Color(hex: "2D3240")

    // MARK: - Properties

    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Play icon in translucent circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 32, height: 32)

                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Start your session")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.44)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(
                color: Color(hex: "2D3240").opacity(0.25),
                radius: 12,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Resume Session Button

struct ResumeSessionButton: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager

    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Resume session")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(-0.44)
                        .foregroundColor(.white)

                    Text(sessionManager.formattedTime)
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                LinearGradient(
                    colors: [.gymBroPrimary, .gymBroPrimaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(
                color: Color.gymBroPrimary.opacity(0.3),
                radius: 12,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StartSessionButton()
        .padding(.horizontal, 20)
        .background(Color.gymBroBackground)
}
