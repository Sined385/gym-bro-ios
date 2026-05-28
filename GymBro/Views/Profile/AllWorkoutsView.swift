//
//  AllWorkoutsView.swift
//  GymBro
//
//  Full-screen vertical list of past workouts pushed from MyProfileView.
//  Reuses ProfileWorkoutCard in its full-width form. Paginates by triggering
//  loadMoreWorkouts when the last card scrolls into view.
//

import SwiftUI

struct AllWorkoutsView: View {
    @ObservedObject var viewModel: MyProfileViewModel
    var onShare: ((ProfileWorkout) -> Void)?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if viewModel.workouts.isEmpty && viewModel.isLoadingWorkouts {
                    ProgressView()
                        .tint(.gymBroPrimary)
                        .padding(.top, 60)
                } else if viewModel.workouts.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    ForEach(viewModel.workouts) { workout in
                        ProfileWorkoutCard(
                            workout: workout,
                            onShare: onShare != nil ? { onShare?(workout) } : nil,
                            cardWidth: nil
                        )
                        .onAppear {
                            if workout.id == viewModel.workouts.last?.id,
                               viewModel.hasMoreWorkouts {
                                Task { await viewModel.loadMoreWorkouts() }
                            }
                        }
                    }

                    if viewModel.hasMoreWorkouts {
                        ProgressView()
                            .tint(.gymBroPrimary)
                            .padding(.vertical, 16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
            Text("No workouts yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
