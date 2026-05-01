//
//  UserProfileViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import Foundation
import Combine

@MainActor
final class UserProfileViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var profile: UserProfile?
    @Published var comparison: AiComparison?
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

    // MARK: - Properties

    let userId: String
    private let networkService: NetworkServiceProtocol
    private var likeInFlight: Set<String> = []

    // MARK: - Initialization

    init(userId: String, networkService: NetworkServiceProtocol) {
        self.userId = userId
        self.networkService = networkService
    }

    // MARK: - Computed

    var isFollowing: Bool {
        profile?.isFollowing ?? false
    }

    var followButtonTitle: String {
        isFollowing ? "Following" : "Follow"
    }

    var recentPosts: [CommunityPost] {
        profile?.recentPosts ?? []
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
        isLoadingComparison = true

        do {
            comparison = try await networkService.request(
                CommunityRouter.userCompare(userId: userId).endpoint,
                responseType: AiComparison.self
            )
        } catch {
            print("[UserProfileVM] comparison failed: \(error)")
        }

        isLoadingComparison = false
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
        if let index = profile?.recentPosts.firstIndex(where: { $0.id == postId }) {
            let post = profile!.recentPosts[index]
            let updated = post.withReactions(
                optimisticToggle(post.reactions ?? [], emoji: emoji),
                reactionCount: optimisticCount(post.reactions ?? [], emoji: emoji)
            )
            updateProfilePost(at: index, with: updated)
        }

        Task {
            do {
                let response = try await networkService.request(
                    CommunityRouter.toggleReaction(postId: postId, emoji: emoji).endpoint,
                    responseType: ReactionResponse.self
                )
                if let index = profile?.recentPosts.firstIndex(where: { $0.id == postId }) {
                    let post = profile!.recentPosts[index]
                    let updated = post.withReactions(response.reactions, reactionCount: response.totalReactionCount)
                    updateProfilePost(at: index, with: updated)
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

    private func updateProfilePost(at index: Int, with updated: CommunityPost) {
        guard let p = profile else { return }
        var posts = p.recentPosts
        posts[index] = updated
        profile = UserProfile(
            user: p.user,
            primaryGoals: p.primaryGoals,
            experienceLevel: p.experienceLevel,
            bodyWeightKg: p.bodyWeightKg,
            memberSince: p.memberSince,
            consistencyStats: p.consistencyStats,
            extendedStats: p.extendedStats,
            followerCount: p.followerCount,
            followingCount: p.followingCount,
            isFollowing: p.isFollowing,
            followsMe: p.followsMe,
            recentPosts: posts,
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
            if let index = profile?.recentPosts.firstIndex(where: { $0.id == postId }) {
                let post = profile!.recentPosts[index]
                updateProfilePost(at: index, with: post.withCommentCount(post.commentCount + 1))
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
