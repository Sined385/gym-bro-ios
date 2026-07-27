//
//  MyProfileView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-24.
//  Redesigned 2026-06-25: tabbed layout (Overview / Workouts / Posts) matching
//  the community profile, reusing the shared profile components.
//

import SwiftUI

struct MyProfileView: View {
    @StateObject private var viewModel: MyProfileViewModel = {
        DependencyContainer.shared.resolve(MyProfileViewModel.self)
    }()
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showFollowList = false
    @State private var followListInitialTab: FollowListTab = .followers
    @State private var selectedTab: ProfileTab = .overview
    @State private var openedPost: OpenedPost?
    @State private var shareURL: URL?
    @EnvironmentObject private var appDataState: AppDataState

    private struct OpenedPost: Identifiable { let id: String }

    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)
    @State private var profileAppearTime: Date?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.gymBroPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if let profile = viewModel.profile {
                        headerCard(profile)
                        followerRow(profile)
                        ProfileTabBar(
                            selected: $selectedTab,
                            counts: [.workouts: profile.consistencyStats.totalSessions]
                        )
                        tabContent(profile)
                    } else if viewModel.errorMessage != nil {
                        errorState
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .containerRelativeFrame(.horizontal)
            }
            .refreshable {
                await viewModel.loadProfile()
                await viewModel.loadWorkouts()
            }
            .background(Color.gymBroBackground.ignoresSafeArea())
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showEditProfile = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gymBroPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gymBroNeutral900)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(
                    initialName: viewModel.profile?.user.fullName ?? "",
                    initialUsername: viewModel.profile?.user.username ?? "",
                    initialAvatarUrl: viewModel.profile?.user.avatarUrl
                )
            }
            .onChange(of: showEditProfile) { _, isPresented in
                if !isPresented { Task { await viewModel.loadProfile() } }
            }
            .navigationDestination(isPresented: $showFollowList) {
                FollowListView(initialTab: followListInitialTab)
            }
            .onChange(of: showFollowList) { _, isPresented in
                if !isPresented { Task { await viewModel.loadProfile() } }
            }
            .fullScreenCover(item: $openedPost) { op in
                ProfilePostsFeedView(viewModel: viewModel, initialPostId: op.id, title: "Posts")
            }
            .onChange(of: selectedTab) { _, tab in
                if tab == .posts { Task { await viewModel.loadPostsIfNeeded() } }
            }
            .task {
                await viewModel.loadIfNeeded()
                await viewModel.loadWorkouts()
            }
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
                if let url = shareURL { ActivityViewController(activityItems: [url]) }
            }
        }
        .analyticsScreen("Profile")
        .onAppear { profileAppearTime = Date() }
        .onDisappear {
            if let start = profileAppearTime {
                let seconds = Int(Date().timeIntervalSince(start))
                if seconds > 0 {
                    analytics.track("profile_time_spent", properties: ["seconds": seconds])
                }
            }
        }
    }

    // MARK: - Header

    private func headerCard(_ profile: MyProfileResponse) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AvatarView(name: profile.user.fullName, avatarUrl: profile.user.avatarUrl, size: 68)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.user.fullName)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Text(metaLine(profile))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gymBroTextSecondary)

                if let goal = profile.primaryGoal ?? profile.primaryGoals?.first, !goal.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "target").font(.system(size: 11))
                        Text(formatGoal(goal)).font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.gymBroPrimary)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Color.gymBroPrimary.opacity(0.10))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private func followerRow(_ profile: MyProfileResponse) -> some View {
        HStack(spacing: 0) {
            statButton("\(profile.followerCount)", String(localized: "Followers")) {
                followListInitialTab = .followers
                showFollowList = true
            }
            Rectangle().fill(Color.gymBroBorderLight).frame(width: 1, height: 28)
            statButton("\(profile.followingCount)", String(localized: "Following")) {
                followListInitialTab = .following
                showFollowList = true
            }
        }
        .padding(.vertical, 11)
        .background(Color.gymBroCardBackground)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gymBroBorderLight, lineWidth: 1))
        .cornerRadius(16)
    }

    private func statButton(_ value: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(value).font(.system(size: 17, weight: .bold)).foregroundColor(.gymBroNeutral900)
                Text(label).font(.system(size: 10, weight: .bold)).foregroundColor(.gymBroTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tabs

    @ViewBuilder
    private func tabContent(_ profile: MyProfileResponse) -> some View {
        switch selectedTab {
        case .overview: overviewTab(profile)
        case .workouts:
            ProfileWorkoutsSection(
                workouts: viewModel.workouts,
                isLoading: viewModel.isLoadingWorkouts,
                hasMore: viewModel.hasMoreWorkouts,
                onLoadMore: { await viewModel.loadMoreWorkouts() },
                onShare: { workout in shareWorkout(workout) }
            )
        case .posts:
            ProfilePostsGrid(viewModel: viewModel) { id in
                openedPost = OpenedPost(id: id)
            }
        }
    }

    @ViewBuilder
    private func overviewTab(_ profile: MyProfileResponse) -> some View {
        if let s = profile.profileStats, let orm = s.oneRepMax,
           orm.bench != nil || orm.squat != nil || orm.deadlift != nil {
            StrengthStatCard(oneRepMax: orm, bodyWeightKg: s.bodyWeightKg ?? profile.bodyWeightKg)
        }

        ConsistencyCard(
            weekStreak: profile.profileStats?.weekStreak ?? 0,
            sessionsPerWeek: profile.profileStats?.avgSessionsPerWeek ?? 0,
            allTimeSessions: profile.consistencyStats.totalSessions
        )

        if let muscles = profile.profileStats?.topMuscleGroups, !muscles.isEmpty {
            MuscleFocusChips(muscles: muscles)
        }
    }

    // MARK: - Misc

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 36)).foregroundColor(.gymBroNeutral400)
            Text("Could not load profile.").font(.system(size: 16, weight: .medium)).foregroundColor(.gymBroTextSecondary)
            Button("Retry") { Task { await viewModel.loadProfile() } }
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.gymBroPrimary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    // MARK: - Share Workout

    /// Routes the profile share button into the builder via pendingShareData.
    private func shareWorkout(_ workout: ProfileWorkout) {
        let activeExercises = workout.exercises.map { he in
            ActiveSessionExercise(
                id: he.id,
                libraryExerciseId: nil,
                name: he.name,
                muscleGroup: he.muscleGroup ?? "Other",
                equipment: "",
                accentColor: he.accentColor,
                stepNumber: he.stepNumber,
                sets: he.sets.map { sd in
                    ActiveSet(
                        id: UUID().uuidString,
                        setNumber: sd.setNumber,
                        weight: sd.weight,
                        weightUnit: sd.weightUnit,
                        reps: sd.reps,
                        isCompleted: true,
                        isBodyweight: sd.isBodyweight
                    )
                },
                supersetGroupId: nil,
                supersetOrder: nil,
                targetSets: he.sets.count,
                targetReps: 0,
                imageUrl: he.imageUrl,
                externalId: he.externalId
            )
        }
        appDataState.pendingShareData = CompletedWorkoutShareData(
            sessionId: workout.id,
            sessionTitle: workout.title,
            exercises: activeExercises,
            effortLevel: 0,
            energyLevel: 0,
            durationMinutes: workout.durationMinutes,
            calories: workout.calories,
            avgHeartRate: workout.avgHeartRate
        )
        analytics.track("profile_workout_share_opened", properties: ["session_id": workout.id])
    }

    // MARK: - Helpers

    private func metaLine(_ profile: MyProfileResponse) -> String {
        var parts: [String] = []
        if let username = profile.user.username, !username.isEmpty { parts.append("@\(username)") }
        if let level = profile.experienceLevel, !level.isEmpty {
            parts.append(ExperienceLevel(rawValue: level.lowercased())?.displayName ?? level.capitalized)
        }
        if let weight = profile.bodyWeightKg { parts.append(String(localized: "\(weight.formattedWeight) kg-str")) }
        return parts.joined(separator: " · ")
    }

    private func formatGoal(_ goal: String) -> String {
        goal.split(separator: ",")
            .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
            .joined(separator: ", ")
    }
}
