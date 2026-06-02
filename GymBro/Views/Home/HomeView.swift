//
//  HomeView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-13.
//

import SwiftUI

struct HomeView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel: HomeViewModel = DependencyContainer.shared.resolve(HomeViewModel.self)
    @StateObject private var pushService: PushNotificationService = DependencyContainer.shared.resolve(PushNotificationService.self)
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showNotifications = false
    @State private var showWorkoutLibrary = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                headerSection
                    .padding(.top, 8)

                // Daily wellness challenge
                if let challenge = viewModel.dailyChallenge {
                    DailyChallengesCard(
                        challenge: challenge,
                        onComplete: { id in
                            Task { await viewModel.completeChallenge(id: id) }
                        }
                    )
                }

                // Motivation card
                MotivationCard(
                    title: viewModel.motivation?.title,
                    message: viewModel.motivation?.message
                )

                // Week calendar
                WeekCalendarCard(
                    completedDayIndices: viewModel.weekCompletedDays,
                    completedDates: viewModel.completedDates,
                    selectedDate: $viewModel.selectedDate,
                    onDayTapped: { date in
                        viewModel.selectDay(date)
                    },
                    onSelectionCleared: {
                        viewModel.clearSelection()
                    },
                    onMonthChanged: { date in
                        Task { await viewModel.loadCompletedDays(forMonth: date) }
                    }
                )

                if viewModel.isShowingHistory {
                    // Session history
                    SessionHistorySection(
                        session: viewModel.sessionHistory!,
                        dayLabel: viewModel.selectedDayLabel
                    )

                    weeklyOverviewCard
                } else if viewModel.selectedDate != nil && viewModel.isLoadingHistory {
                    // Loading history
                    ProgressView()
                        .tint(.gymBroPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let completed = viewModel.todayCompletedSession {
                    StartSessionButton {
                        Task { await viewModel.startCustomSession() }
                    }

                    MyWorkoutsButton { showWorkoutLibrary = true }

                    SessionHistorySection(session: completed, dayLabel: "Today")

                    weeklyOverviewCard
                } else if sessionManager.isSessionActive {
                    // Session in progress — show resume button
                    ResumeSessionButton {
                        sessionManager.expand()
                    }
                } else if viewModel.isRestDay {
                    // Rest day — start session + recovery card
                    StartSessionButton {
                        Task { await viewModel.startCustomSession() }
                    }

                    MyWorkoutsButton { showWorkoutLibrary = true }

                    RestDayCard(
                        weekWorkoutsCompleted: viewModel.weekWorkoutsCompleted,
                        weekWorkoutsTotal: viewModel.weekWorkoutsTotal,
                        weekVolumeKg: viewModel.weekVolumeKg,
                        weekStreak: viewModel.weekStreak,
                        personalRecords: viewModel.motivation?.personalRecords ?? [],
                        restingHeartRate: viewModel.restingHeartRate,
                        latestWeightKg: viewModel.latestWeightKg,
                        todayActiveEnergy: viewModel.todayActiveEnergy,
                        latestBodyFat: viewModel.latestBodyFat,
                        latestLeanBodyMass: viewModel.latestLeanBodyMass,
                        todayStepCount: viewModel.todayStepCount,
                        lastNightSleep: viewModel.lastNightSleep,
                        latestHRV: viewModel.latestHRV,
                        latestVO2Max: viewModel.latestVO2Max,
                        todayWalkingDistance: viewModel.todayWalkingDistance,
                        weekAvgDurationMinutes: viewModel.weekAvgDurationMinutes,
                        weekTotalCalories: viewModel.weekTotalCalories
                    )

                    weeklyOverviewCard
                } else if viewModel.isTrainingDay, let planned = viewModel.plannedWorkout {
                    // Training day — show start button + planned workout
                    StartSessionButton {
                        Task { await viewModel.startCustomSession() }
                    }

                    MyWorkoutsButton { showWorkoutLibrary = true }

                    PlannedWorkoutCard(
                        plannedWorkout: planned,
                        onStart: { Task { await viewModel.startPlannedWorkout() } },
                        isStarting: viewModel.isStartingSession
                    )

                    weeklyOverviewCard
                } else {
                    // No plan — start button + quick workout fallback
                    StartSessionButton {
                        Task { await viewModel.startCustomSession() }
                    }

                    MyWorkoutsButton { showWorkoutLibrary = true }

                    quickWorkoutSection

                    weeklyOverviewCard
                }

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .sheet(isPresented: $showWorkoutLibrary) {
            WorkoutLibraryView()
                .environmentObject(sessionManager)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.gymBroPrimary)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
            _ = await pushService.requestPermission()
            await pushService.reregisterTokenIfNeeded()
            await pushService.fetchUnreadCount()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await pushService.fetchUnreadCount() }
            }
        }
        .onChange(of: showNotifications) { _, isShowing in
            if !isShowing {
                Task { await pushService.fetchUnreadCount() }
            }
        }
        .analyticsScreen("Home")
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            // Profile avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.gymBroPrimary, .gymBroPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Text(String(viewModel.userName.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            // Greeting
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "737373"))

                Text(viewModel.userName)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.44)
                    .foregroundColor(.gymBroNeutral900)
            }

            Spacer()

            // Notification bell
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: Color.black.opacity(0.05),
                                radius: 4,
                                x: 0,
                                y: 2
                            )

                        Image(systemName: "bell")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gymBroNeutral900)
                    }

                    if pushService.unreadCount > 0 {
                        Text("\(min(pushService.unreadCount, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.gymBroPrimary)
                            .clipShape(Capsule())
                            .offset(x: 6, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
        }
    }

    // MARK: - Weekly Overview

    @ViewBuilder
    private var weeklyOverviewCard: some View {
        if let overview = viewModel.weeklyOverview {
            WeeklyOverviewCard(
                overview: overview,
                weekWorkouts: viewModel.weekWorkoutsCompleted,
                weekVolumeKg: viewModel.weekVolumeKg,
                weekAvgDuration: viewModel.weekAvgDurationMinutes,
                weekCalories: viewModel.weekTotalCalories,
                avgWorkouts: viewModel.prev3AvgWorkouts,
                avgVolumeKg: viewModel.prev3AvgVolumeKg,
                avgDuration: viewModel.prev3AvgDurationMinutes,
                avgCalories: viewModel.prev3AvgCalories
            )
        }
    }

    // MARK: - Quick Workout Section

    private var quickWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Workout")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.44)
                .foregroundColor(.gymBroNeutral900)

            QuickWorkoutCard(
                session: viewModel.quickWorkout,
                onStart: { Task { await viewModel.startQuickWorkout() } },
                isStarting: viewModel.isStartingSession
            )
        }
    }
}

// MARK: - My Workouts Button

private struct MyWorkoutsButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.gymBroPrimary.opacity(0.10))
                        .frame(width: 32, height: 32)

                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gymBroPrimary)
                }

                Text("Library")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.44)
                    .foregroundColor(.gymBroNeutral900)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.gymBroNeutral200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
}
