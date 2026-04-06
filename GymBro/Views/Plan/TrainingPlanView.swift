//
//  TrainingPlanView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import SwiftUI

struct TrainingPlanView: View {

    @StateObject private var viewModel: TrainingPlanViewModel = {
        DependencyContainer.shared.resolve(TrainingPlanViewModel.self)
    }()
    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)

    var body: some View {
        ZStack {
            Color.gymBroBackground
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.days.isEmpty {
                ProgressView()
                    .tint(Color(hex: "E86A75"))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        weekSection
                        timelineSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
        .task {
            analytics.track("plan_opened", properties: [:])
            await viewModel.loadIfNeeded()
        }
        .analyticsScreen("TrainingPlan")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Plan")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.5)
                .foregroundColor(.gymBroNeutral900)

            PlanGoalBadge(displayText: viewModel.goalDisplayText)
        }
    }

    // MARK: - Week Info

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("This Week")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Text(viewModel.weekLabel)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Color(hex: "7A82F6"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "7A82F6").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("Weekly progression")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "737373"))
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.days.enumerated()), id: \.element.id) { index, day in
                let dayState = computeState(for: day, at: index)
                let isLast = index == viewModel.days.count - 1

                HStack(alignment: .top, spacing: 14) {
                    // Timeline indicator
                    PlanTimelineIndicator(state: dayState, isLast: isLast)

                    // Day content
                    VStack(alignment: .leading, spacing: 6) {
                        // Day label
                        Text(day.dayLabel)
                            .font(.system(size: 13, weight: .bold))
                            .tracking(0.3)
                            .foregroundColor(
                                dayState == .upNext
                                    ? Color(hex: "E86A75")
                                    : Color(hex: "737373")
                            )
                            .padding(.top, 6)

                        // Day card
                        PlanDayCard(
                            day: day,
                            state: dayState,
                            onStartSession: {
                                Task {
                                    await viewModel.startPlanSession(dayId: day.id)
                                }
                            },
                            isStarting: viewModel.isStartingSession
                        )
                    }
                }
                .padding(.bottom, isLast ? 0 : 4)
            }
        }
    }

    // MARK: - State Computation

    private func computeState(for day: PlanDayData, at index: Int) -> PlanDayState {
        if day.status == "completed" {
            return .completed
        }

        if day.status == "skipped" {
            return .skipped
        }

        if day.dayType == "rest" {
            return .rest
        }

        // The first pending training day at or after todayIndex is "up next"
        if day.status == "pending" && day.dayType == "training" {
            let isUpNext = isFirstPendingTrainingDay(at: index)
            return isUpNext ? .upNext : .future
        }

        return .future
    }

    private func isFirstPendingTrainingDay(at targetIndex: Int) -> Bool {
        for (index, day) in viewModel.days.enumerated() {
            if day.dayType == "training" && day.status == "pending" {
                return index == targetIndex
            }
        }
        return false
    }
}

#Preview {
    TrainingPlanView()
        .inject(dependencies: .shared)
}
