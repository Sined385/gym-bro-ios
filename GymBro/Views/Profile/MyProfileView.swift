//
//  MyProfileView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-24.
//

import SwiftUI

struct MyProfileView: View {
    @StateObject private var viewModel: MyProfileViewModel = {
        DependencyContainer.shared.resolve(MyProfileViewModel.self)
    }()
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var isSharingWorkout = false
    @State private var shareURL: URL?
    @State private var showFollowList = false
    @State private var followListInitialTab: FollowListTab = .followers

    private let networkService: NetworkServiceProtocol = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)
    @State private var profileAppearTime: Date?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.gymBroPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if let profile = viewModel.profile {
                        headerCard(profile)
                        followerRow(profile)
                        consistencySection(profile.consistencyStats)
                        statsGrid(profile.extendedStats)

                        ProfileWorkoutsSection(
                            workouts: viewModel.workouts,
                            isLoading: viewModel.isLoadingWorkouts,
                            hasMore: viewModel.hasMoreWorkouts,
                            onLoadMore: { await viewModel.loadMoreWorkouts() },
                            onShare: { workout in
                                Task { await shareWorkout(workout) }
                            }
                        )

                        if !profile.extendedStats.personalRecords.isEmpty {
                            personalRecordsSection(profile.extendedStats.personalRecords)
                        }

                        recentPostsSection(profile.recentPosts)
                    } else if viewModel.errorMessage != nil {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 36))
                                .foregroundColor(.gymBroNeutral400)
                            Text("Could not load profile.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                            Button("Retry") {
                                Task { await viewModel.loadProfile() }
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.gymBroPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }

                    Spacer()
                        .frame(height: 40)
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
                    Button {
                        showEditProfile = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gymBroPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gymBroNeutral900)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(
                    initialName: viewModel.profile?.user.fullName ?? "",
                    initialUsername: viewModel.profile?.user.username ?? "",
                    initialAvatarUrl: viewModel.profile?.user.avatarUrl
                )
            }
            .onChange(of: showEditProfile) { _, isPresented in
                if !isPresented {
                    // Reload profile after edit sheet is dismissed
                    Task { await viewModel.loadProfile() }
                }
            }
            .navigationDestination(isPresented: $showFollowList) {
                FollowListView(initialTab: followListInitialTab)
            }
            .onChange(of: showFollowList) { _, isPresented in
                if !isPresented {
                    // Reload profile to update follower/following counts
                    Task { await viewModel.loadProfile() }
                }
            }
            .task {
                await viewModel.loadIfNeeded()
                await viewModel.loadWorkouts()
            }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } }
            )) {
                if let url = shareURL {
                    ActivityViewController(activityItems: [url])
                }
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

    // MARK: - Header Card

    private func headerCard(_ profile: MyProfileResponse) -> some View {
        HStack(spacing: 14) {
            AvatarView(
                name: profile.user.fullName,
                avatarUrl: profile.user.avatarUrl,
                size: 80
            )
            .overlay(
                Circle()
                    .stroke(Color(hex: "F5F5F5"), lineWidth: 3)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.user.fullName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                if let username = profile.user.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }

                if let goals = profile.primaryGoals, !goals.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gymBroPrimary)
                        Text(goals.map { formatGoal($0) }.joined(separator: ", "))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gymBroPrimary)
                    }
                }

                HStack(spacing: 4) {
                    if let level = profile.experienceLevel {
                        Text(level.capitalized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                    }
                    if profile.experienceLevel != nil && profile.bodyWeightKg != nil {
                        Text("•")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                    }
                    if let weight = profile.bodyWeightKg {
                        Text("\(weight.formattedWeight) kg")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 12)
    }

    // MARK: - Follower/Following Row

    private func followerRow(_ profile: MyProfileResponse) -> some View {
        HStack(spacing: 0) {
            Button {
                followListInitialTab = .followers
                showFollowList = true
            } label: {
                VStack(spacing: 2) {
                    Text("\(profile.followerCount)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    Text("Followers")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 32)

            Button {
                followListInitialTab = .following
                showFollowList = true
            } label: {
                VStack(spacing: 2) {
                    Text("\(profile.followingCount)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    Text("Following")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 16)
        .background(Color.gymBroCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Consistency Section

    private func consistencySection(_ stats: ConsistencyStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consistency")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            HStack(spacing: 12) {
                consistencyCard(
                    label: "THIS WEEK",
                    value: stats.thisWeek ?? 0,
                    valueColor: .gymBroNeutral900
                )
                consistencyCard(
                    label: "THIS MONTH",
                    value: stats.thisMonth ?? stats.last30DaysSessions,
                    valueColor: Color(hex: "30C08D")
                )
                consistencyCard(
                    label: "THIS YEAR",
                    value: stats.thisYear ?? stats.totalSessions,
                    valueColor: Color(hex: "E86A75")
                )
            }
        }
    }

    private func consistencyCard(label: String, value: Int, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gymBroTextSecondary)
                .tracking(0.5)

            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(valueColor)

            Text("sessions")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.gymBroCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Stats Grid

    private func statsGrid(_ stats: ExtendedStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                statCard(
                    icon: "flame.fill",
                    iconColor: Color(hex: "E86A75"),
                    label: "Total Duration",
                    value: "\(stats.totalDurationMinutes / 60)h \(stats.totalDurationMinutes % 60)m"
                )
                statCard(
                    icon: "bolt.fill",
                    iconColor: Color(hex: "F5A623"),
                    label: "Total Calories",
                    value: formatNumber(stats.totalCalories)
                )
                statCard(
                    icon: "clock.fill",
                    iconColor: Color(hex: "30C08D"),
                    label: "Avg Session",
                    value: "\(stats.avgSessionDuration) min"
                )
                statCard(
                    icon: "scalemass.fill",
                    iconColor: Color(hex: "5B8DEF"),
                    label: "Total Weight",
                    value: formatWeight(stats.totalWeightLifted)
                )
            }
        }
    }

    private func statCard(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(iconColor)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(hex: "2D3240"))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Personal Records

    private func personalRecordsSection(_ records: [PersonalRecord]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "F5A623"))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.exerciseName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.gymBroNeutral900)

                            Text("\(record.weight.formattedWeight) \(record.weightUnit) x \(record.reps) reps")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)

                    if index < records.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .background(Color.gymBroCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
            )
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Recent Posts

    private func recentPostsSection(_ posts: [CommunityPost]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            if posts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.gymBroNeutral400)
                    Text("No posts yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                    Text("Share your workouts from the Community tab!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.gymBroCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
                )
                .cornerRadius(24)
            } else {
                ForEach(posts) { post in
                    VStack(spacing: 0) {
                        PostCardView(
                            post: post,
                            onReaction: { emoji in viewModel.toggleReaction(postId: post.id, emoji: emoji) },
                            onComment: { viewModel.toggleComments(postId: post.id) },
                            onUserTap: { _ in },
                            onDelete: {
                                Task { await viewModel.deletePost(post.id) }
                            },
                            isCommentsExpanded: viewModel.expandedComments.contains(post.id),
                            onShare: {
                                shareURL = URL(string: "https://gyymjaam.com/p/\(post.id)")
                            }
                        )

                        if viewModel.expandedComments.contains(post.id) {
                            CommentsSection(
                                comments: viewModel.commentsMap[post.id] ?? [],
                                onSubmit: { content in
                                    Task {
                                        await viewModel.addComment(postId: post.id, content: content)
                                    }
                                },
                                onUserTap: { _ in }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .background(Color.gymBroCardBackground)
                            .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
                            .offset(y: -8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatGoal(_ goal: String) -> String {
        goal.split(separator: ",")
            .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
            .joined(separator: ", ")
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000.0)
        }
        return "\(value)"
    }

    private func formatWeight(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk kg", value / 1000.0)
        }
        return "\(Int(value)) kg"
    }
}
