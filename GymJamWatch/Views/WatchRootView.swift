//
//  WatchRootView.swift
//  GymJamWatch
//
//  Routes between idle state and active workout.
//

import SwiftUI

struct WatchRootView: View {

    @EnvironmentObject var sessionViewModel: WatchSessionViewModel
    @EnvironmentObject var connectivityService: PhoneConnectivityService

    var body: some View {
        Group {
            if sessionViewModel.showSummary, let summary = sessionViewModel.workoutSummary {
                WorkoutSummaryView(summary: summary) {
                    sessionViewModel.dismissSummary()
                }
            } else if sessionViewModel.isSessionActive {
                ActiveWorkoutView()
            } else {
                IdleView()
            }
        }
        .onAppear {
            connectivityService.activate()
        }
    }
}

// MARK: - Idle View (no active session)

struct IdleView: View {

    @EnvironmentObject var connectivityService: PhoneConnectivityService

    private var canStartPlanned: Bool {
        guard let plan = connectivityService.todayPlan else { return false }
        return plan.dayType != "rest" && plan.planDayId != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 36))
                    .foregroundColor(WatchColors.primary)
                    .padding(.top, 4)

                Text("GymJam")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                if let plan = connectivityService.todayPlan {
                    TodayPlanCard(plan: plan)
                }

                if connectivityService.isRequestingSession {
                    ProgressView()
                        .tint(WatchColors.primary)
                        .padding(.top, 4)
                    Text("Starting...")
                        .font(WatchTypography.caption)
                        .foregroundColor(WatchColors.textSecondary)
                } else {
                    // Start buttons
                    VStack(spacing: 8) {
                        if canStartPlanned {
                            Button {
                                connectivityService.sendRequestSessionStart(
                                    type: "planned",
                                    planDayId: connectivityService.todayPlan?.planDayId
                                )
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 12))
                                    Text("Start Planned")
                                        .font(WatchTypography.button)
                                }
                            }
                            .buttonStyle(WatchPrimaryButtonStyle())
                        }

                        if canStartPlanned {
                            Button {
                                connectivityService.sendRequestSessionStart(type: "custom")
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12))
                                    Text("Custom Workout")
                                        .font(WatchTypography.button)
                                }
                            }
                            .buttonStyle(WatchOutlineButtonStyle())
                        } else {
                            Button {
                                connectivityService.sendRequestSessionStart(type: "custom")
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12))
                                    Text("Custom Workout")
                                        .font(WatchTypography.button)
                                }
                            }
                            .buttonStyle(WatchPrimaryButtonStyle())
                        }
                    }
                }

                if !connectivityService.isPhoneReachable {
                    HStack(spacing: 4) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 11))
                        Text("iPhone not connected")
                            .font(WatchTypography.micro)
                    }
                    .foregroundColor(WatchColors.textSecondary)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Today Plan Card

struct TodayPlanCard: View {
    let plan: WatchTodayPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.dayLabel)
                .font(WatchTypography.caption)
                .foregroundColor(WatchColors.textSecondary)

            if let title = plan.sessionTitle {
                Text(title)
                    .font(WatchTypography.sectionTitle)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }

            if plan.dayType == "rest" {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .foregroundColor(WatchColors.purple)
                    Text("Rest Day")
                        .font(WatchTypography.body)
                        .foregroundColor(WatchColors.purple)
                }
            } else {
                if !plan.muscleGroups.isEmpty {
                    Text(plan.muscleGroups.joined(separator: " · "))
                        .font(WatchTypography.caption)
                        .foregroundColor(WatchColors.textSecondary)
                }

                Text("\(plan.exercises.count) exercises")
                    .font(WatchTypography.caption)
                    .foregroundColor(WatchColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(WatchColors.cardBackground)
        .cornerRadius(12)
    }
}
