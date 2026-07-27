//
//  UserProfileView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//  Redesigned 2026-06-24: tabbed layout (Overview / PRs / Workouts / Posts)
//  leading with an AI head-to-head comparison and grouped stats, plus an
//  Instagram-style posts grid + popover feed.
//

import SwiftUI

struct UserProfileView: View {
    let userId: String
    @StateObject private var viewModel: UserProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSharingWorkout = false
    @State private var shareURL: URL?
    @State private var reportTarget: (contentType: String, contentId: String)?
    @State private var blockTarget: (userId: String, userName: String)?
    @State private var openedPost: OpenedPost?
    @State private var showFollowList = false
    @State private var followListTab: FollowListTab = .followers

    private struct OpenedPost: Identifiable { let id: String }

    private let networkService: NetworkServiceProtocol = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)

    init(userId: String) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(
            userId: userId,
            networkService: DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
        ))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.gymBroPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if let profile = viewModel.profile {
                    headerCard(profile)
                    if !profile.isOwnProfile { followButton }
                    followerRow(profile)
                    ProfileTabBar(selected: $viewModel.selectedTab, counts: tabCounts(profile))
                    tabContent(profile)
                } else if viewModel.errorMessage != nil {
                    errorState
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
            .containerRelativeFrame(.horizontal)
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle(viewModel.profile?.user.fullName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $openedPost) { op in
            ProfilePostsFeedView(
                viewModel: viewModel,
                initialPostId: op.id,
                title: viewModel.profile?.user.fullName ?? String(localized: "Posts")
            )
        }
        .sheet(isPresented: $showFollowList) {
            NavigationStack {
                FollowListView(initialTab: followListTab, userId: userId)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let profile = viewModel.profile, !profile.isOwnProfile {
                    Menu {
                        Button {
                            reportTarget = (contentType: "user", contentId: userId)
                        } label: {
                            Label("Report User", systemImage: "flag")
                        }
                        Button(role: .destructive) {
                            blockTarget = (userId: userId, userName: profile.user.fullName)
                        } label: {
                            Label("Block User", systemImage: "person.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .task {
            await viewModel.loadProfile()
            await viewModel.loadComparison()
        }
        .onChange(of: viewModel.selectedTab) { _, tab in
            switch tab {
            case .workouts: Task { await viewModel.loadWorkoutsIfNeeded() }
            case .posts: Task { await viewModel.loadPostsIfNeeded() }
            default: break
            }
        }
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
            if let url = shareURL { ActivityViewController(activityItems: [url]) }
        }
        .sheet(isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } })) {
            if let target = reportTarget {
                ReportContentView(contentType: target.contentType, contentId: target.contentId) {
                    reportTarget = nil
                }
            }
        }
        .confirmationDialog(
            "Block \(blockTarget?.userName ?? "user")?",
            isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let target = blockTarget {
                    Task { await viewModel.blockUser(userId: target.userId); dismiss() }
                }
                blockTarget = nil
            }
            Button("Cancel", role: .cancel) { blockTarget = nil }
        } message: {
            Text("You won't see their content and they won't be able to interact with you.")
        }
    }

    // MARK: - Header

    private func headerCard(_ profile: UserProfile) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AvatarView(name: profile.user.fullName, avatarUrl: profile.user.avatarUrl, size: 68)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.user.fullName)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    if profile.followsMe {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark").font(.system(size: 7, weight: .black))
                            Text("Follows you").font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.gymBroNeutral600)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.gymBroNeutral100)
                        .clipShape(Capsule())
                    }
                }

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

    private var followButton: some View {
        Button {
            Task { await viewModel.toggleFollow() }
        } label: {
            Group {
                if viewModel.isFollowActionLoading {
                    ProgressView().tint(viewModel.isFollowing ? .gymBroNeutral600 : .white)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text(viewModel.followButtonTitle).font(.system(size: 14, weight: .bold))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundColor(viewModel.isFollowing ? .gymBroNeutral600 : .white)
            .background(viewModel.isFollowing ? Color.gymBroNeutral100 : Color.gymBroPrimary)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(viewModel.isFollowing ? Color.gymBroBorderLight : .clear, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }

    private func followerRow(_ profile: UserProfile) -> some View {
        HStack(spacing: 0) {
            statButton("\(profile.followerCount ?? 0)", String(localized: "Followers")) {
                followListTab = .followers
                showFollowList = true
            }
            divider
            statButton("\(profile.followingCount ?? 0)", String(localized: "Following")) {
                followListTab = .following
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

    private var divider: some View {
        Rectangle().fill(Color.gymBroBorderLight).frame(width: 1, height: 28)
    }

    // MARK: - Tabs

    private func tabCounts(_ profile: UserProfile) -> [ProfileTab: Int] {
        [.workouts: profile.consistencyStats.totalSessions]
    }

    @ViewBuilder
    private func tabContent(_ profile: UserProfile) -> some View {
        switch viewModel.selectedTab {
        case .overview: overviewTab(profile)
        case .workouts:
            ProfileWorkoutsSection(
                workouts: viewModel.workouts,
                isLoading: viewModel.isLoadingWorkouts,
                hasMore: viewModel.hasMoreWorkouts,
                onLoadMore: { await viewModel.loadMoreWorkouts() },
                onShare: { workout in Task { await shareWorkout(workout) } }
            )
        case .posts:
            ProfilePostsGrid(viewModel: viewModel) { id in
                openedPost = OpenedPost(id: id)
            }
        }
    }

    @ViewBuilder
    private func overviewTab(_ profile: UserProfile) -> some View {
        if !profile.isOwnProfile {
            ProfileComparisonCard(
                comparison: viewModel.comparison,
                isLoading: viewModel.isLoadingComparison,
                isPremium: viewModel.isPremium,
                otherName: profile.user.fullName,
                onUpgrade: { viewModel.subscriptionManager.showPaywall = true }
            )
        }

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

    private func shareWorkout(_ workout: ProfileWorkout) async {
        guard !isSharingWorkout else { return }
        isSharingWorkout = true
        do {
            let template = try await networkService.request(
                TemplateRouter.create(name: workout.title, sessionIds: [workout.id]).endpoint,
                responseType: WorkoutTemplate.self
            )
            let response = try await networkService.request(
                TemplateRouter.share(templateId: template.id).endpoint,
                responseType: ShareTemplateResponse.self
            )
            isSharingWorkout = false
            shareURL = URL(string: response.shareUrl)
        } catch {
            isSharingWorkout = false
        }
    }

    // MARK: - Helpers

    private func metaLine(_ profile: UserProfile) -> String {
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
