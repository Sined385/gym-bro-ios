//
//  ProfileWorkoutsSection.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import SwiftUI

struct ProfileWorkoutsSection: View {
    let workouts: [ProfileWorkout]
    let isLoading: Bool
    let hasMore: Bool
    let onLoadMore: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workouts")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            if workouts.isEmpty && isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.gymBroPrimary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if workouts.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(workouts) { workout in
                            ProfileWorkoutCard(workout: workout)
                                .onAppear {
                                    if workout.id == workouts.last?.id, hasMore {
                                        Task { await onLoadMore() }
                                    }
                                }
                        }

                        if hasMore {
                            ProgressView()
                                .tint(.gymBroPrimary)
                                .frame(width: 60)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
            Text("No workouts yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.gymBroCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .cornerRadius(24)
    }
}
