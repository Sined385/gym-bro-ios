//
//  UserProfileViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import Foundation
import Combine

/// Top-level tabs on the redesigned community profile.
enum ProfileTab: String, CaseIterable, Identifiable {
    case overview, workouts, posts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return String(localized: "Overview")
        case .workouts: return String(localized: "Workouts")
        case .posts: return String(localized: "Posts")
        }
    }
}

/// Filter chips on the Posts grid.
enum PostFilter: String, CaseIterable, Identifiable {
    case all, workouts, photos
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return String(localized: "All")
        case .workouts: return "Workouts"
        case .photos: return String(localized: "Photos")
        }
    }
}

@MainActor
final class UserProfileViewModel: ObservableObject, ProfilePostsSource {

    /// Other users' posts aren't deletable from here.
    let canDeletePosts = false
    func deletePost(_ id: String) async {}


    // MARK: - Published Properties

    @Published var profile: UserProfile?
    @Published var comparison: HeadToHead?
    @Published var isLoading: Bool = false
    @Published var isLoadingComparison: Bool = false
    @Published var isFollowActionLoading: Bool = false
    @Published var errorMessage: String?
    @Published var expandedComments: Set<String> = []
    @Published var commentsMap: [String: [PostComment]] = [:]
    @Published var workouts: [ProfileWorkout] = []
    @Published var isLoadingWorkouts: Bool = false
    @Published var hasMoreWorkouts: Bool = false
    private var workoutCursor: String?
    private var hasLoadedWorkouts = false

    // Tabs + posts grid
    @Published var selectedTab: ProfileTab = .overview
    @Published var postFilter: PostFilter = .all
    @Published var posts: [CommunityPost] = []
    @Published var isLoadingPosts: Bool = false
    @Published var hasMorePosts: Bool = false
    private var postsCursor: String?
    private var hasLoadedPosts = false

    // MARK: - Properties

    let userId: String
    private let networkService: NetworkServiceProtocol
    let subscriptionManager: SubscriptionManager
    private var likeInFlight: Set<String> = []

    // MARK: - Initialization

    init(
        userId: String,
        networkService: NetworkServiceProtocol,
        subscriptionManager: SubscriptionManager = DependencyContainer.shared.resolve(SubscriptionManager.self)
    ) {
        self.userId = userId
        self.networkService = networkService
        self.subscriptionManager = subscriptionManager
    }

    // MARK: - Computed

    var isPremium: Bool {
        subscriptionManager.isPremium
    }

    var isFollowing: Bool {
        profile?.isFollowing ?? false
    }

    var followButtonTitle: String {
        isFollowing ? String(localized: "Following") : String(localized: "Follow")
    }

    var recentPosts: [CommunityPost] {
        profile?.recentPosts ?? []
    }

    /// Posts shown in the grid, after the active filter chip.
    var filteredPosts: [CommunityPost] {
        switch postFilter {
        case .all:
            return posts
        case .workouts:
            return posts.filter { $0.workoutAttachment != nil }
        case .photos:
            return posts.filter { ($0.photoUrl?.isEmpty == false) }
        }
    }

    // MARK: - Data Loading

    func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            profile = try await networkService.request(
                CommunityRouter.userProfile(userId: userId).endpoint,
                responseType: UserProfile.self
            )
        } catch {
            errorMessage = "Could not load profile."
        }

        isLoading = false
    }

    func loadComparison() async {
        guard profile != nil, profile?.isOwnProfile == false else { return }
        // Premium-only AI feature — the server skips generation for free users
        // and the card shows an upgrade teaser instead.
        guard isPremium else { return }
        isLoadingComparison = true

        do {
            comparison = try await networkService.request(
                CommunityRouter.userCompare(userId: userId).endpoint,
                responseType: HeadToHead.self
            )
        } catch {
            print("[UserProfileVM] comparison failed: \(error)")
        }

        isLoadingComparison = false
    }

    // MARK: - Posts Grid

    func loadPostsIfNeeded() async {
        guard !hasLoadedPosts else { return }
        hasLoadedPosts = true
        await loadPosts()
    }

    func loadPosts() async {
        guard !isLoadingPosts else { return }
        isLoadingPosts = true
        do {
            let response = try await networkService.request(
                CommunityRouter.userPosts(userId: userId, cursor: nil, limit: 18).endpoint,
                responseType: ProfilePostsResponse.self
            )
            posts = response.posts
            postsCursor = response.nextCursor
            hasMorePosts = response.nextCursor != nil
        } catch { }
        isLoadingPosts = false
    }

    func loadMorePosts() async {
        guard hasMorePosts, !isLoadingPosts, let cursor = postsCursor else { return }
        isLoadingPosts = true
        do {
            let response = try await networkService.request(
                CommunityRouter.userPosts(userId: userId, cursor: cursor, limit: 18).endpoint,
                responseType: ProfilePostsResponse.self
            )
            posts.append(contentsOf: response.posts)
            postsCursor = response.nextCursor
            hasMorePosts = response.nextCursor != nil
        } catch { }
        isLoadingPosts = false
    }

    func loadWorkoutsIfNeeded() async {
        guard !hasLoadedWorkouts else { return }
        hasLoadedWorkouts = true
        await loadWorkouts()
    }

    // MARK: - Workout History

    func loadWorkouts() async {
        guard !isLoadingWorkouts else { return }
        isLoadingWorkouts = true

        do {
            let response = try await networkService.request(
                CommunityRouter.userWorkouts(userId: userId, cursor: nil, limit: 10).endpoint,
                responseType: ProfileWorkoutsResponse.self
            )
            workouts = response.workouts
            workoutCursor = response.nextCursor
            hasMoreWorkouts = response.hasMore
        } catch { }

        isLoadingWorkouts = false
    }

    func loadMoreWorkouts() async {
        guard hasMoreWorkouts, !isLoadingWorkouts, let cursor = workoutCursor else { return }
        isLoadingWorkouts = true

        do {
            let response = try await networkService.request(
                CommunityRouter.userWorkouts(userId: userId, cursor: cursor, limit: 10).endpoint,
                responseType: ProfileWorkoutsResponse.self
            )
            workouts.append(contentsOf: response.workouts)
            workoutCursor = response.nextCursor
            hasMoreWorkouts = response.hasMore
        } catch { }

        isLoadingWorkouts = false
    }

    // MARK: - Post Interactions

    func toggleReaction(postId: String, emoji: String) {
        let key = "\(postId):\(emoji)"
        guard !likeInFlight.contains(key) else { return }
        likeInFlight.insert(key)

        // Optimistic update
        if let post = findPost(postId) {
            applyPostUpdate(post.withReactions(
                optimisticToggle(post.reactions ?? [], emoji: emoji),
                reactionCount: optimisticCount(post.reactions ?? [], emoji: emoji)
            ))
        }

        Task {
            do {
                let response = try await networkService.request(
                    CommunityRouter.toggleReaction(postId: postId, emoji: emoji).endpoint,
                    responseType: ReactionResponse.self
                )
                if let post = findPost(postId) {
                    applyPostUpdate(post.withReactions(response.reactions, reactionCount: response.totalReactionCount))
                }
            } catch { }
            likeInFlight.remove(key)
        }
    }

    private func optimisticToggle(_ reactions: [PostReaction], emoji: String) -> [PostReaction] {
        var result = reactions
        if let ri = result.firstIndex(where: { $0.emoji == emoji }) {
            let r = result[ri]
            if r.isReacted {
                let c = max(0, r.count - 1)
                if c == 0 { result.remove(at: ri) }
                else { result[ri] = PostReaction(emoji: emoji, count: c, isReacted: false) }
            } else {
                result[ri] = PostReaction(emoji: emoji, count: r.count + 1, isReacted: true)
            }
        } else {
            result.append(PostReaction(emoji: emoji, count: 1, isReacted: true))
        }
        return result
    }

    private func optimisticCount(_ reactions: [PostReaction], emoji: String) -> Int {
        optimisticToggle(reactions, emoji: emoji).reduce(0) { $0 + $1.count }
    }

    /// Look up a post by id across both the grid (`posts`) and the profile's
    /// `recentPosts` — either surface can drive an interaction.
    private func findPost(_ id: String) -> CommunityPost? {
        posts.first(where: { $0.id == id }) ?? profile?.recentPosts.first(where: { $0.id == id })
    }

    /// Write an updated post back to every array that holds it.
    private func applyPostUpdate(_ updated: CommunityPost) {
        if let i = posts.firstIndex(where: { $0.id == updated.id }) {
            posts[i] = updated
        }
        guard let p = profile,
              let i = p.recentPosts.firstIndex(where: { $0.id == updated.id }) else { return }
        var recent = p.recentPosts
        recent[i] = updated
        profile = UserProfile(
            user: p.user,
            primaryGoal: p.primaryGoal,
            primaryGoals: p.primaryGoals,
            experienceLevel: p.experienceLevel,
            bodyWeightKg: p.bodyWeightKg,
            memberSince: p.memberSince,
            consistencyStats: p.consistencyStats,
            extendedStats: p.extendedStats,
            profileStats: p.profileStats,
            followerCount: p.followerCount,
            followingCount: p.followingCount,
            isFollowing: p.isFollowing,
            followsMe: p.followsMe,
            recentPosts: recent,
            isOwnProfile: p.isOwnProfile
        )
    }

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

            // Update comment count
            if let post = findPost(postId) {
                applyPostUpdate(post.withCommentCount(post.commentCount + 1))
            }
        } catch { }
    }

    // MARK: - Block

    func blockUser(userId: String) async {
        let _ = try? await networkService.request(
            CommunityRouter.blockUser(userId: userId).endpoint,
            responseType: SuccessResponse.self
        )
    }

    // MARK: - Follow Actions

    func toggleFollow() async {
        guard !isFollowActionLoading else { return }
        isFollowActionLoading = true

        if isFollowing {
            do {
                _ = try await networkService.request(
                    CommunityRouter.unfollowUser(userId: userId).endpoint,
                    responseType: SuccessResponse.self
                )
                await loadProfile()
            } catch { }
        } else {
            do {
                _ = try await networkService.request(
                    CommunityRouter.followUser(userId: userId).endpoint,
                    responseType: FollowResponse.self
                )
                await loadProfile()
            } catch { }
        }

        isFollowActionLoading = false
    }

}
