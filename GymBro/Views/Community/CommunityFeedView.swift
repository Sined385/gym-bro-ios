//
//  CommunityFeedView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import SwiftUI

enum CommunityDestination: Hashable {
    case userProfile(userId: String)
    case postDetail(postId: String)
}

struct CommunityFeedView: View {
    @StateObject private var viewModel: CommunityFeedViewModel = DependencyContainer.shared.resolve(CommunityFeedViewModel.self)
    @EnvironmentObject var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @EnvironmentObject var appDataState: AppDataState
    @State private var navigationPath = NavigationPath()
    @State private var shareURL: URL?
    @State private var reportTarget: (contentType: String, contentId: String)?
    @State private var blockTarget: (userId: String, userName: String)?
    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Search bar
                        searchBar
                            .padding(.top, 8)

                        // Search results or feed
                        if !viewModel.searchQuery.isEmpty {
                            searchResultsList
                        } else {
                            // Tab pills
                            FeedTabPills(selectedTab: $viewModel.selectedTab) { tab in
                                viewModel.switchTab(to: tab)
                            }

                            // Suggested profiles (global tab only)
                            if viewModel.selectedTab == "global" && !viewModel.suggestedUsers.isEmpty {
                                SuggestedProfilesSection(
                                    users: viewModel.suggestedUsers,
                                    onFollow: { userId in viewModel.followSuggestedUser(userId: userId) },
                                    onUserTap: { userId in
                                        navigationPath.append(CommunityDestination.userProfile(userId: userId))
                                    }
                                )
                            }

                            // Content
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.gymBroPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 60)
                            } else if viewModel.posts.isEmpty {
                                emptyStateView
                            } else {
                                feedContent
                            }
                        }

                        Spacer()
                            .frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                }
                .background(Color.gymBroBackground.ignoresSafeArea())

                // Floating create post button
                if viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.isShowingNewPost = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.gymBroPrimary, .gymBroPrimaryDark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                                .shadow(color: .gymBroPrimary.opacity(0.3), radius: 8, x: 0, y: 4)

                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, sessionManager.isCollapsed ? 80 : 16)
                }
            }
            .task {
                await viewModel.loadIfNeeded()
                viewModel.loadSuggestedUsersIfNeeded()
            }
            .refreshable {
                await viewModel.loadFeed()
            }
            // ShareEditorView drops the freshly-posted post into this slot
            // before dismissing. Inject it at the top of the feed, then clear
            // the slot so navigating away + back doesn't re-insert it.
            .onChange(of: appDataState.pendingFeedPost) { _, post in
                if let post {
                    viewModel.onPostCreated(post)
                    appDataState.pendingFeedPost = nil
                }
            }
            .sheet(isPresented: $viewModel.isShowingNewPost) {
                NewPostView { post in
                    viewModel.onPostCreated(post)
                }
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
                        Task { await viewModel.blockUser(userId: target.userId) }
                    }
                    blockTarget = nil
                }
                Button("Cancel", role: .cancel) {
                    blockTarget = nil
                }
            } message: {
                Text("You won't see their content and they won't be able to interact with you.")
            }
            .navigationDestination(for: CommunityDestination.self) { destination in
                switch destination {
                case .userProfile(let userId):
                    UserProfileView(userId: userId)
                case .postDetail(let postId):
                    PostDetailView(postId: postId)
                }
            }
            .onChange(of: deepLinkRouter.pendingPostId) { _, postId in
                if let postId {
                    navigationPath.append(CommunityDestination.postDetail(postId: postId))
                    deepLinkRouter.pendingPostId = nil
                }
            }
            .onChange(of: deepLinkRouter.pendingUserId) { _, userId in
                if let userId {
                    navigationPath.append(CommunityDestination.userProfile(userId: userId))
                    deepLinkRouter.pendingUserId = nil
                }
            }
        }
        .analyticsScreen("Community")
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gymBroNeutral400)

            TextField("Search users...", text: $viewModel.searchQuery)
                .font(.system(size: 15))
                .foregroundColor(.gymBroTextPrimary)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.searchUsers()
                }

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gymBroNeutral400)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.gymBroNeutral100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            if viewModel.isSearching {
                ProgressView()
                    .tint(.gymBroPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if viewModel.searchResults.isEmpty {
                Text("No users found")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gymBroTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { user in
                        Button {
                            navigationPath.append(CommunityDestination.userProfile(userId: user.id))
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(name: user.fullName, avatarUrl: user.avatarUrl, size: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.fullName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.gymBroNeutral900)
                                    if let username = user.username {
                                        Text("@\(username)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.gymBroTextSecondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    viewModel.toggleFollowSearchResult(userId: user.id)
                                } label: {
                                    Text(user.isFollowing ? "Following" : "Follow")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(user.isFollowing ? Color(hex: "30C08D") : Color.gymBroPrimary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.posts) { post in
                VStack(spacing: 0) {
                    PostCardView(
                        post: post,
                        onReaction: { emoji in viewModel.toggleReaction(postId: post.id, emoji: emoji) },
                        onComment: { viewModel.toggleComments(postId: post.id) },
                        onUserTap: { userId in
                            navigationPath.append(CommunityDestination.userProfile(userId: userId))
                        },
                        onFollow: post.isOwnPost ? nil : {
                            viewModel.toggleFollow(userId: post.user.id)
                        },
                        onDelete: post.isOwnPost ? {
                            let postId = post.id
                            Task { await viewModel.deletePost(postId) }
                        } : nil,
                        onReport: post.isOwnPost ? nil : {
                            reportTarget = (contentType: "post", contentId: post.id)
                        },
                        onBlockUser: post.isOwnPost ? nil : {
                            blockTarget = (userId: post.user.id, userName: post.user.fullName)
                        },
                        isCommentsExpanded: viewModel.expandedComments.contains(post.id),
                        onShare: {
                            shareURL = URL(string: "\(AppEnvironment.current.shareDomain)/p/\(post.id)")
                            analytics.track("post_shared", properties: ["post_id": post.id])
                        }
                    )
                    .onTapGesture {
                        analytics.track("post_opened", properties: ["post_id": post.id])
                        navigationPath.append(CommunityDestination.postDetail(postId: post.id))
                    }

                    // Inline comments
                    if viewModel.expandedComments.contains(post.id) {
                        CommentsSection(
                            comments: viewModel.commentsMap[post.id] ?? [],
                            onSubmit: { content in
                                Task {
                                    await viewModel.addComment(postId: post.id, content: content)
                                }
                            },
                            onUserTap: { userId in
                                navigationPath.append(CommunityDestination.userProfile(userId: userId))
                            },
                            onReportComment: { commentId in
                                reportTarget = (contentType: "comment", contentId: commentId)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .background(Color.gymBroCardBackground)
                        .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
                        .offset(y: -8)
                    }
                }
            }

            // Load more trigger
            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(.gymBroPrimary)
                    .padding(.vertical, 20)
            } else if !viewModel.posts.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
            }
        }
    }

    // MARK: - Empty State

    private let darkCard = Color(hex: "2D3240")

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 56, height: 56)

                Image(systemName: viewModel.selectedTab == "following" ? "person.2.fill" : "text.bubble.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }

            Text(viewModel.selectedTab == "following"
                 ? "Follow users to see their updates here."
                 : "No posts yet. Be the first to share!")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "A1A1A1"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .background(darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - RoundedCorner helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
