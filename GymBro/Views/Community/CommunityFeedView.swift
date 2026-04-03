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
    @State private var navigationPath = NavigationPath()
    @State private var shareURL: URL?
    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header
                    headerSection
                        .padding(.top, 8)

                    // Tab pills
                    FeedTabPills(selectedTab: $viewModel.selectedTab) { tab in
                        viewModel.switchTab(to: tab)
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
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.posts) { post in
                                VStack(spacing: 0) {
                                    PostCardView(
                                        post: post,
                                        onLike: { viewModel.toggleLike(postId: post.id) },
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
                                        isCommentsExpanded: viewModel.expandedComments.contains(post.id),
                                        onShare: {
                                            shareURL = URL(string: "https://gyymjaam.com/p/\(post.id)")
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

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.gymBroBackground.ignoresSafeArea())
            .task {
                await viewModel.loadIfNeeded()
            }
            .refreshable {
                await viewModel.loadFeed()
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
        }
        .analyticsScreen("Community")
    }

    // MARK: - Header

    private let darkCard = Color(hex: "2D3240")

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color.gymBroPrimary.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gymBroPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Community")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.44)
                    .foregroundColor(.white)

                Text("See what everyone's up to")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "A1A1A1"))
            }

            Spacer()

            Button {
                viewModel.isShowingNewPost = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 40, height: 40)

                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(
            color: Color(hex: "2D3240").opacity(0.15),
            radius: 12.5,
            x: 0,
            y: 20
        )
    }

    // MARK: - Empty State

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
