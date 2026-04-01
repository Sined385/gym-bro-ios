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

    func toggleLike(postId: String) {
        guard !likeInFlight.contains(postId) else { return }
        likeInFlight.insert(postId)

        // Optimistic update
        if let index = profile?.recentPosts.firstIndex(where: { $0.id == postId }) {
            let post = profile!.recentPosts[index]
            let newIsLiked = !post.isLiked
            let newCount = newIsLiked ? post.likeCount + 1 : max(0, post.likeCount - 1)
            let updated = CommunityPost(
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
            var posts = profile!.recentPosts
            posts[index] = updated
            profile = UserProfile(
                user: profile!.user,
                primaryGoals: profile!.primaryGoals,
                experienceLevel: profile!.experienceLevel,
                bodyWeightKg: profile!.bodyWeightKg,
                consistencyStats: profile!.consistencyStats,
                isFollowing: profile!.isFollowing,
                followsMe: profile!.followsMe,
                recentPosts: posts,
                isOwnProfile: profile!.isOwnProfile
            )
        }

        Task {
            do {
                let response = try await networkService.request(
                    CommunityRouter.toggleLike(postId: postId).endpoint,
                    responseType: LikeResponse.self
                )
                if let index = profile?.recentPosts.firstIndex(where: { $0.id == postId }) {
                    let post = profile!.recentPosts[index]
                    let updated = CommunityPost(
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
                    var posts = profile!.recentPosts
                    posts[index] = updated
                    profile = UserProfile(
                        user: profile!.user,
                        primaryGoals: profile!.primaryGoals,
                        experienceLevel: profile!.experienceLevel,
                        bodyWeightKg: profile!.bodyWeightKg,
                        consistencyStats: profile!.consistencyStats,
                        isFollowing: profile!.isFollowing,
                        followsMe: profile!.followsMe,
                        recentPosts: posts,
                        isOwnProfile: profile!.isOwnProfile
                    )
                }
            } catch { }
            likeInFlight.remove(postId)
        }
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
                let updated = CommunityPost(
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
                var posts = profile!.recentPosts
                posts[index] = updated
                profile = UserProfile(
                    user: profile!.user,
                    primaryGoals: profile!.primaryGoals,
                    experienceLevel: profile!.experienceLevel,
                    bodyWeightKg: profile!.bodyWeightKg,
                    consistencyStats: profile!.consistencyStats,
                    isFollowing: profile!.isFollowing,
                    followsMe: profile!.followsMe,
                    recentPosts: posts,
                    isOwnProfile: profile!.isOwnProfile
                )
            }
        } catch { }
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
