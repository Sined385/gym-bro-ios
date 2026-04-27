//
//  UserProfileView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
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
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.gymBroPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if let profile = viewModel.profile {
                    profileHeader(profile)
                    followerRow(profile)
                    consistencySection(profile.consistencyStats)

                    if let stats = profile.extendedStats {
                        statsGrid(stats)
                    }

                    ProfileWorkoutsSection(
                        workouts: viewModel.workouts,
                        isLoading: viewModel.isLoadingWorkouts,
                        hasMore: viewModel.hasMoreWorkouts,
                        onLoadMore: { await viewModel.loadMoreWorkouts() },
                        onShare: { workout in
                            Task { await shareWorkout(workout) }
                        }
                    )

                    if let stats = profile.extendedStats, !stats.personalRecords.isEmpty {
                        personalRecordsSection(stats.personalRecords)
                    }

                    if !profile.isOwnProfile {
                        aiComparisonSection
                    }

                    if !profile.recentPosts.isEmpty {
                        recentPostsSection(profile.recentPosts)
                    }
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
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle(viewModel.profile?.user.fullName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let profile = viewModel.profile, !profile.isOwnProfile {
                    HStack(spacing: 8) {
                        navFollowButton

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
        }
        .task {
            await viewModel.loadProfile()
            async let workoutsTask: () = viewModel.loadWorkouts()
            async let comparisonTask: () = viewModel.loadComparison()
            _ = await (workoutsTask, comparisonTask)
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let url = shareURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .sheet(isPresented: Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        )) {
            if let target = reportTarget {
                ReportContentView(contentType: target.contentType, contentId: target.contentId) {
                    reportTarget = nil
                }
            }
        }
        .confirmationDialog(
            "Block \(blockTarget?.userName ?? "user")?",
            isPresented: Binding(
                get: { blockTarget != nil },
                set: { if !$0 { blockTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let target = blockTarget {
                    Task {
                        await viewModel.blockUser(userId: target.userId)
                        dismiss()
                    }
                }
                blockTarget = nil
            }
            Button("Cancel", role: .cancel) {
                blockTarget = nil
            }
        } message: {
            Text("You won't see their content and they won't be able to interact with you.")
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

    // MARK: - Nav Follow Button

    private var navFollowButton: some View {
        Button {
            Task { await viewModel.toggleFollow() }
        } label: {
            if viewModel.isFollowActionLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(viewModel.followButtonTitle)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.isFollowing ? Color(hex: "30C08D") : Color(hex: "2D3240"))
        .buttonBorderShape(.capsule)
    }

    // MARK: - Profile Header

    private func profileHeader(_ profile: UserProfile) -> some View {
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

    // MARK: - Follower/Following Row

    private func followerRow(_ profile: UserProfile) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(profile.followerCount ?? 0)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                Text("Followers")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gymBroTextSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 32)

            VStack(spacing: 2) {
                Text("\(profile.followingCount ?? 0)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                Text("Following")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gymBroTextSecondary)
            }
            .frame(maxWidth: .infinity)
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

    // MARK: - Comparison

    private var aiComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comparison")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            if viewModel.isLoadingComparison {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.gymBroPrimary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let comparison = viewModel.comparison {
                comparisonCard(comparison)
            }
        }
    }

    private func comparisonCard(_ comparison: AiComparison) -> some View {
        VStack(spacing: 0) {
            // Header with avatars and VS
            comparisonHeader(comparison)

            // Stats comparison rows
            if comparison.currentUser.avgSessionsPerWeek != nil || comparison.otherUser.avgSessionsPerWeek != nil {
                VStack(spacing: 0) {
                    comparisonStatRow(
                        label: "SESSIONS/WK",
                        myValue: comparison.currentUser.avgSessionsPerWeek.map { String(format: "%.1f", $0) },
                        theirValue: comparison.otherUser.avgSessionsPerWeek.map { String(format: "%.1f", $0) }
                    )
                    comparisonStatRow(
                        label: "VOLUME TREND",
                        myValue: comparison.currentUser.volumeTrend?.capitalized,
                        theirValue: comparison.otherUser.volumeTrend?.capitalized
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            // Lift rows
            VStack(spacing: 0) {
                comparisonLiftRow(
                    label: "BENCH PRESS",
                    myValue: comparison.currentUser.benchPress,
                    theirValue: comparison.otherUser.benchPress
                )
                comparisonLiftRow(
                    label: "SQUAT",
                    myValue: comparison.currentUser.squat,
                    theirValue: comparison.otherUser.squat
                )
                comparisonLiftRow(
                    label: "DEADLIFT",
                    myValue: comparison.currentUser.deadlift,
                    theirValue: comparison.otherUser.deadlift
                )
                comparisonBodyWeightRow(
                    myWeight: comparison.currentUser.bodyWeightKg,
                    theirWeight: comparison.otherUser.bodyWeightKg
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Structured comparison sections or fallback
            if let analysis = comparison.comparison {
                structuredAnalysisSections(analysis)
            } else if let overlapText = comparison.overlapAnalysis {
                overlapAnalysisSection(overlapText)
            }
        }
        .background(Color.gymBroCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .cornerRadius(32)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private let centerColumnWidth: CGFloat = 110

    private func comparisonHeader(_ comparison: AiComparison) -> some View {
        HStack(spacing: 0) {
            // You
            VStack(spacing: 4) {
                AvatarView(
                    name: comparison.currentUser.fullName,
                    size: 56
                )
                .overlay(
                    Circle()
                        .stroke(Color.gymBroPrimary, lineWidth: 2.5)
                )

                Text("You")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
            }
            .frame(maxWidth: .infinity)

            Text("VS")
                .font(.system(size: 14, weight: .medium))
                .italic()
                .foregroundColor(.gymBroTextSecondary)
                .frame(width: centerColumnWidth)

            // Them
            VStack(spacing: 4) {
                AvatarView(
                    name: comparison.otherUser.fullName,
                    size: 56
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "2D3240"), lineWidth: 2.5)
                )

                Text(comparison.otherUser.fullName.components(separatedBy: " ").first ?? comparison.otherUser.fullName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(hex: "FAFAFA"))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "F5F5F5")),
            alignment: .bottom
        )
    }

    private func comparisonLiftRow(label: String, myValue: Double?, theirValue: Double?) -> some View {
        let myWins: Bool? = {
            guard let m = myValue, let t = theirValue else { return nil }
            return m > t
        }()

        return HStack(spacing: 0) {
            // My value
            VStack(alignment: .center, spacing: 0) {
                Text(myValue != nil ? "\(Int(myValue!))" : "—")
                    .font(.system(size: myWins == true ? 18 : 16, weight: .bold))
                    .foregroundColor(myWins == true ? Color(hex: "30C08D") : (myWins == false ? Color(hex: "E86A75") : .gymBroTextSecondary))
                if myValue != nil {
                    Text("LBS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gymBroTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)

            // Center pill label
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gymBroTextSecondary)
                .tracking(0.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "F5F5F5"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "E5E5E5").opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(20)
                .frame(width: centerColumnWidth)

            // Their value
            VStack(alignment: .center, spacing: 0) {
                Text(theirValue != nil ? "\(Int(theirValue!))" : "—")
                    .font(.system(size: myWins == false ? 18 : 16, weight: .bold))
                    .foregroundColor(myWins == false ? Color(hex: "30C08D") : (myWins == true ? Color(hex: "E86A75") : .gymBroTextSecondary))
                if theirValue != nil {
                    Text("LBS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gymBroTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
    }

    private func comparisonBodyWeightRow(myWeight: Double?, theirWeight: Double?) -> some View {
        HStack(spacing: 0) {
            Text(myWeight != nil ? "\(Int(myWeight!)) kg" : "—")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "525252"))
                .frame(maxWidth: .infinity)

            Text("BODY WEIGHT")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gymBroTextSecondary)
                .tracking(0.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "F5F5F5"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "E5E5E5").opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(20)
                .frame(width: centerColumnWidth)

            Text(theirWeight != nil ? "\(Int(theirWeight!)) kg" : "—")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "525252"))
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
    }

    private func comparisonStatRow(label: String, myValue: String?, theirValue: String?) -> some View {
        HStack(spacing: 0) {
            Text(myValue ?? "—")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "525252"))
                .frame(maxWidth: .infinity)

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gymBroTextSecondary)
                .tracking(0.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "F5F5F5"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "E5E5E5").opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(20)
                .frame(width: centerColumnWidth)

            Text(theirValue ?? "—")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "525252"))
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }

    private func structuredAnalysisSections(_ analysis: ComparisonAnalysis) -> some View {
        VStack(spacing: 0) {
            // Summary
            analysisSectionBlock(
                icon: "sparkles",
                title: "SUMMARY",
                text: analysis.summary,
                background: Color(hex: "E86A75").opacity(0.05)
            )

            // Training Patterns
            if !analysis.trainingPatterns.isEmpty {
                analysisSectionBlock(
                    icon: "figure.run",
                    title: "TRAINING PATTERNS",
                    text: analysis.trainingPatterns,
                    background: Color.clear
                )
            }

            // Volume Trends
            if !analysis.volumeTrends.isEmpty {
                analysisSectionBlock(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "VOLUME TRENDS",
                    text: analysis.volumeTrends,
                    background: Color.clear
                )
            }

            // Strengths - side by side
            strengthsSection(analysis.strengths)

            // Recommendation
            if !analysis.recommendation.isEmpty {
                analysisSectionBlock(
                    icon: "lightbulb.fill",
                    title: "RECOMMENDATION",
                    text: analysis.recommendation,
                    background: Color(hex: "E86A75").opacity(0.05)
                )
            }
        }
    }

    private func analysisSectionBlock(icon: String, title: String, text: String, background: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gymBroPrimary)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gymBroPrimary)
                    .tracking(0.5)
            }

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "404040"))
                .multilineTextAlignment(.center)
                .lineSpacing(4.75)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(background)
    }

    private func strengthsSection(_ strengths: ComparisonStrengths) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gymBroPrimary)
                Text("STRENGTHS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gymBroPrimary)
                    .tracking(0.5)
            }

            HStack(alignment: .top, spacing: 10) {
                // You
                VStack(spacing: 6) {
                    Text("You")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    Text(strengths.currentUser)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "525252"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "30C08D").opacity(0.06))
                .cornerRadius(16)

                // Them
                VStack(spacing: 6) {
                    Text("Them")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    Text(strengths.otherUser)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "525252"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "2D3240").opacity(0.06))
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func overlapAnalysisSection(_ analysis: String) -> some View {
        VStack(spacing: 8) {
            Text("ANALYSIS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gymBroPrimary)
                .tracking(0.5)

            Text(analysis)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "404040"))
                .multilineTextAlignment(.center)
                .lineSpacing(4.75)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "E86A75").opacity(0.05))
    }

    // MARK: - Recent Posts

    private func recentPostsSection(_ posts: [CommunityPost]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            ForEach(posts) { post in
                VStack(spacing: 0) {
                    PostCardView(
                        post: post,
                        onLike: { viewModel.toggleLike(postId: post.id) },
                        onComment: { viewModel.toggleComments(postId: post.id) },
                        onUserTap: { _ in },
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
