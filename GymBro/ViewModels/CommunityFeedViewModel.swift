//
//  CommunityFeedViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import Foundation
import Combine

@MainActor
final class CommunityFeedViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedTab: String = "global"
    @Published var posts: [CommunityPost] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var expandedComments: Set<String> = []
    @Published var commentsMap: [String: [PostComment]] = [:]
    @Published var isShowingNewPost: Bool = false

    // MARK: - Pagination

    private var cursor: String?
    private var hasMore: Bool = true
    private var likeInFlight: Set<String> = []

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let analyticsService: AnalyticsTrackingServiceProtocol
    private var hasLoaded = false

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, analyticsService: AnalyticsTrackingServiceProtocol) {
        self.networkService = networkService
        self.analyticsService = analyticsService
    }

    // MARK: - Load If Needed

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadFeed()
    }

    // MARK: - Feed Loading

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        cursor = nil
        hasMore = true

        do {
            let response = try await networkService.request(
                CommunityRouter.feed(tab: selectedTab, cursor: nil, limit: 20).endpoint,
                responseType: FeedResponse.self
            )
            posts = response.posts
            cursor = response.nextCursor
            hasMore = response.hasMore
            expandCommentsForAllPosts()
            await loadAllComments()
        } catch {
            errorMessage = "Could not load feed. Pull to retry."
        }

        isLoading = false
    }

    private func expandCommentsForAllPosts() {
        for post in posts where post.commentCount > 0 {
            expandedComments.insert(post.id)
        }
    }

    private func loadAllComments() async {
        await withTaskGroup(of: Void.self) { group in
            for post in posts where post.commentCount > 0 {
                group.addTask { [weak self] in
                    await self?.loadComments(postId: post.id)
                }
            }
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, cursor != nil else { return }
        isLoadingMore = true

        do {
            let response = try await networkService.request(
                CommunityRouter.feed(tab: selectedTab, cursor: cursor, limit: 20).endpoint,
                responseType: FeedResponse.self
            )
            posts.append(contentsOf: response.posts)
            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            // Silently fail on load more
        }

        isLoadingMore = false
    }

    func switchTab(to tab: String) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        Task {
            await loadFeed()
        }
    }

    // MARK: - Like Toggle

    func toggleLike(postId: String) {
        guard !likeInFlight.contains(postId) else { return }
        likeInFlight.insert(postId)

        // Optimistic update
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            let post = posts[index]
            let newIsLiked = !post.isLiked
            if newIsLiked {
                analyticsService.track("post_liked", properties: ["post_id": postId])
            }
            let newCount = newIsLiked ? post.likeCount + 1 : max(0, post.likeCount - 1)
            posts[index] = CommunityPost(
                id: post.id,
                user: post.user,
                content: post.content,
                visibility: post.visibility,
                photoUrl: post.photoUrl,
                workoutAttachment: post.workoutAttachment,
                likeCount: newCount,
                commentCount: post.commentCount,
                isLiked: newIsLiked,
                isFollowingAuthor: post.isFollowingAuthor,
                isOwnPost: post.isOwnPost,
                createdAt: post.createdAt
            )
        }

        Task {
            do {
                let response = try await networkService.request(
                    CommunityRouter.toggleLike(postId: postId).endpoint,
                    responseType: LikeResponse.self
                )
                // Update with server values
                if let index = posts.firstIndex(where: { $0.id == postId }) {
                    let post = posts[index]
                    posts[index] = CommunityPost(
                        id: post.id,
                        user: post.user,
                        content: post.content,
                        visibility: post.visibility,
                        photoUrl: post.photoUrl,
                        workoutAttachment: post.workoutAttachment,
                        likeCount: response.likeCount,
                        commentCount: post.commentCount,
                        isLiked: response.isLiked,
                        isFollowingAuthor: post.isFollowingAuthor,
                        isOwnPost: post.isOwnPost,
                        createdAt: post.createdAt
                    )
                }
            } catch {
                // Revert optimistic update
                await loadFeed()
            }
            likeInFlight.remove(postId)
        }
    }

    // MARK: - Comments

    func toggleComments(postId: String) {
        if expandedComments.contains(postId) {
            expandedComments.remove(postId)
        } else {
            expandedComments.insert(postId)
            if commentsMap[postId] == nil {
                Task { await loadComments(postId: postId) }
            }
        }
    }

    func loadComments(postId: String) async {
        do {
            let response = try await networkService.request(
                CommunityRouter.getComments(postId: postId, cursor: nil, limit: 20).endpoint,
                responseType: CommentsResponse.self
            )
            commentsMap[postId] = response.comments
        } catch {
            commentsMap[postId] = []
        }
    }

    func addComment(postId: String, content: String) async {
        do {
            let comment = try await networkService.request(
                CommunityRouter.createComment(postId: postId, content: content).endpoint,
                responseType: PostComment.self
            )
            var existing = commentsMap[postId] ?? []
            existing.insert(comment, at: 0)
            commentsMap[postId] = existing
            analyticsService.track("post_commented", properties: ["post_id": postId])

            // Update comment count
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let post = posts[index]
                posts[index] = CommunityPost(
                    id: post.id,
                    user: post.user,
                    content: post.content,
                    visibility: post.visibility,
                    photoUrl: post.photoUrl,
                    workoutAttachment: post.workoutAttachment,
                    likeCount: post.likeCount,
                    commentCount: post.commentCount + 1,
                    isLiked: post.isLiked,
                    isFollowingAuthor: post.isFollowingAuthor,
                    isOwnPost: post.isOwnPost,
                    createdAt: post.createdAt
                )
            }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Follow Toggle

    private var followInFlight: Set<String> = []

    func toggleFollow(userId: String) {
        guard !followInFlight.contains(userId) else { return }
        followInFlight.insert(userId)

        // Find current follow state from the first post by this user
        let isCurrentlyFollowing = posts.first(where: { $0.user.id == userId })?.isFollowingAuthor ?? false

        // Optimistic update — toggle all posts by this user
        for i in posts.indices where posts[i].user.id == userId {
            let post = posts[i]
            posts[i] = CommunityPost(
                id: post.id,
                user: post.user,
                content: post.content,
                visibility: post.visibility,
                photoUrl: post.photoUrl,
                workoutAttachment: post.workoutAttachment,
                likeCount: post.likeCount,
                commentCount: post.commentCount,
                isLiked: post.isLiked,
                isFollowingAuthor: !isCurrentlyFollowing,
                isOwnPost: post.isOwnPost,
                createdAt: post.createdAt
            )
        }

        Task {
            do {
                if isCurrentlyFollowing {
                    _ = try await networkService.request(
                        CommunityRouter.unfollowUser(userId: userId).endpoint,
                        responseType: SuccessResponse.self
                    )
                } else {
                    _ = try await networkService.request(
                        CommunityRouter.followUser(userId: userId).endpoint,
                        responseType: FollowResponse.self
                    )
                }
            } catch {
                // Revert optimistic update
                for i in posts.indices where posts[i].user.id == userId {
                    let post = posts[i]
                    posts[i] = CommunityPost(
                        id: post.id,
                        user: post.user,
                        content: post.content,
                        visibility: post.visibility,
                        photoUrl: post.photoUrl,
                        workoutAttachment: post.workoutAttachment,
                        likeCount: post.likeCount,
                        commentCount: post.commentCount,
                        isLiked: post.isLiked,
                        isFollowingAuthor: isCurrentlyFollowing,
                        isOwnPost: post.isOwnPost,
                        createdAt: post.createdAt
                    )
                }
            }
            followInFlight.remove(userId)
        }
    }

    // MARK: - Delete Post

    func deletePost(_ postId: String) async {
        do {
            _ = try await networkService.request(
                CommunityRouter.deletePost(postId: postId).endpoint,
                responseType: SuccessResponse.self
            )
            posts.removeAll { $0.id == postId }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Block User

    func blockUser(userId: String) async {
        let _ = try? await networkService.request(
            CommunityRouter.blockUser(userId: userId).endpoint,
            responseType: SuccessResponse.self
        )
        posts.removeAll { $0.user.id == userId }
    }

    // MARK: - Post Created Callback

    func onPostCreated(_ post: CommunityPost) {
        posts.insert(post, at: 0)
    }

}
