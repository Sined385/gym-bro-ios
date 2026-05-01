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

    // Search
    @Published var searchQuery: String = ""
    @Published var searchResults: [SearchUserResult] = []
    @Published var isSearching: Bool = false

    // Suggested
    @Published var suggestedUsers: [SuggestedUser] = []

    // MARK: - Pagination

    private var cursor: String?
    private var hasMore: Bool = true
    private var reactionInFlight: Set<String> = []

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let analyticsService: AnalyticsTrackingServiceProtocol
    private var hasLoaded = false
    private var searchTask: Task<Void, Never>?
    private var suggestedLoaded = false

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

    // MARK: - Reaction Toggle

    func toggleReaction(postId: String, emoji: String) {
        let key = "\(postId):\(emoji)"
        guard !reactionInFlight.contains(key) else { return }
        reactionInFlight.insert(key)

        // Optimistic update
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            let post = posts[index]
            var reactions = post.reactions ?? []
            if let ri = reactions.firstIndex(where: { $0.emoji == emoji }) {
                let r = reactions[ri]
                if r.isReacted {
                    let newCount = max(0, r.count - 1)
                    if newCount == 0 {
                        reactions.remove(at: ri)
                    } else {
                        reactions[ri] = PostReaction(emoji: emoji, count: newCount, isReacted: false)
                    }
                } else {
                    reactions[ri] = PostReaction(emoji: emoji, count: r.count + 1, isReacted: true)
                    analyticsService.track("post_reacted", properties: ["post_id": postId, "emoji": emoji])
                }
            } else {
                reactions.append(PostReaction(emoji: emoji, count: 1, isReacted: true))
                analyticsService.track("post_reacted", properties: ["post_id": postId, "emoji": emoji])
            }
            let totalCount = reactions.reduce(0) { $0 + $1.count }
            posts[index] = post.withReactions(reactions, reactionCount: totalCount)
        }

        Task {
            do {
                let response = try await networkService.request(
                    CommunityRouter.toggleReaction(postId: postId, emoji: emoji).endpoint,
                    responseType: ReactionResponse.self
                )
                if let index = posts.firstIndex(where: { $0.id == postId }) {
                    let post = posts[index]
                    posts[index] = post.withReactions(response.reactions, reactionCount: response.totalReactionCount)
                }
            } catch {
                await loadFeed()
            }
            reactionInFlight.remove(key)
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

            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let post = posts[index]
                posts[index] = post.withCommentCount(post.commentCount + 1)
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

        let isCurrentlyFollowing = posts.first(where: { $0.user.id == userId })?.isFollowingAuthor ?? false

        for i in posts.indices where posts[i].user.id == userId {
            posts[i] = posts[i].withFollowing(!isCurrentlyFollowing)
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
                for i in posts.indices where posts[i].user.id == userId {
                    posts[i] = posts[i].withFollowing(isCurrentlyFollowing)
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

    // MARK: - User Search

    func searchUsers() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }

            do {
                let response = try await networkService.request(
                    CommunityRouter.searchUsers(query: query, limit: 15).endpoint,
                    responseType: SearchUsersResponse.self
                )
                guard !Task.isCancelled else { return }
                searchResults = response.users
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
            }
            isSearching = false
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
        searchTask?.cancel()
    }

    func toggleFollowSearchResult(userId: String) {
        guard let index = searchResults.firstIndex(where: { $0.id == userId }) else { return }
        let wasFollowing = searchResults[index].isFollowing
        searchResults[index].isFollowing = !wasFollowing

        Task {
            do {
                if wasFollowing {
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
                if let i = searchResults.firstIndex(where: { $0.id == userId }) {
                    searchResults[i].isFollowing = wasFollowing
                }
            }
        }
    }

    // MARK: - Suggested Users

    func loadSuggestedUsersIfNeeded() {
        guard !suggestedLoaded else { return }
        suggestedLoaded = true

        Task {
            do {
                let response = try await networkService.request(
                    CommunityRouter.suggestedUsers(limit: 10).endpoint,
                    responseType: SuggestedUsersResponse.self
                )
                suggestedUsers = response.users
            } catch {
                suggestedUsers = []
            }
        }
    }

    func followSuggestedUser(userId: String) {
        suggestedUsers.removeAll { $0.id == userId }

        Task {
            _ = try? await networkService.request(
                CommunityRouter.followUser(userId: userId).endpoint,
                responseType: FollowResponse.self
            )
        }
    }

}
