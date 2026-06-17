//
//  SessionHeader.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

struct SessionHeader: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @EnvironmentObject var favoritesService: FavoritesService

    let isSuperset: Bool
    let exerciseIndex: String
    let libraryExerciseId: String?
    let onBack: () -> Void

    var body: some View {
        HStack {
            // Back button
            Button { onBack() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .stroke(Color.gymBroNeutral100, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Center: exercise counter + timer
            VStack(spacing: 2) {
                if !isSuperset {
                    Text("EXERCISE \(exerciseIndex)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundColor(.gymBroPrimary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 14))
                        .foregroundColor(.gymBroNeutral600)
                    Text(sessionManager.formattedTime)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(.gymBroNeutral900)
                }
            }

            Spacer()

            if let libraryId = libraryExerciseId {
                favoriteHeartButton(libraryExerciseId: libraryId)
            } else {
                // Balance the back button width when no heart is shown.
                Color.clear.frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func favoriteHeartButton(libraryExerciseId: String) -> some View {
        let isFavorite = favoritesService.isFavorite(libraryExerciseId)
        return Button {
            Task { await favoritesService.toggle(exerciseId: libraryExerciseId) }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle()
                            .stroke(Color.gymBroNeutral100, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFavorite ? .gymBroPrimary : .gymBroNeutral900)
            }
        }
        .buttonStyle(.plain)
    }
}
