//
//  SessionConflictSheet.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-06.
//

import SwiftUI

struct SessionConflictOverlay: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {} // Block taps, no dismiss

            // Bottom card
            VStack(spacing: 20) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "F5A623"))

                // Title
                Text("Active Workout in Progress")
                    .font(.gymBroHeaderMedium)
                    .foregroundColor(.gymBroTextPrimary)

                // Subtitle
                Text("Starting a new session will end your current workout. All unsaved progress will be lost.")
                    .font(.gymBroBody)
                    .foregroundColor(.gymBroTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Session summary card
                let summary = sessionManager.conflictSessionSummary
                VStack(spacing: 12) {
                    Text(summary.title)
                        .font(.gymBroHeaderSmall)
                        .foregroundColor(.gymBroTextPrimary)

                    HStack(spacing: 24) {
                        Label(summary.formattedTime, systemImage: "clock")
                        Label("\(summary.exerciseCount) exercises", systemImage: "dumbbell")
                        Label("\(summary.completedSets) sets", systemImage: "checkmark.circle")
                    }
                    .font(.gymBroCaption)
                    .foregroundColor(.gymBroTextSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 24)

                // Continue button (primary)
                Button {
                    sessionManager.cancelReplaceSession()
                } label: {
                    Text("Continue Current Workout")
                        .font(.gymBroButton)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "E86A75"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                // End & Start New button (destructive)
                Button {
                    sessionManager.confirmReplaceSession()
                } label: {
                    Text("End & Start New")
                        .font(.gymBroButton)
                        .foregroundColor(.red)
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(Color.gymBroBackground)
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .transition(.move(edge: .bottom))
        }
    }
}

