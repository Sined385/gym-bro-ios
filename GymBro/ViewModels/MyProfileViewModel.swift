//
//  MyProfileViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-24.
//

import Foundation
import Combine

@MainActor
final class MyProfileViewModel: ObservableObject, ProfilePostsSource {

    // MARK: - Published Properties

    @Published var profile: MyProfileResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var expandedComments: Set<String> = []
    @Published var commentsMap: [String: [PostComment]] = [:]
    @Published var workouts: [ProfileWorkout] = []
    @Published var isLoadingWorkouts: Bool = false
    @Published var hasMoreWorkouts: Bool = false
    private var workoutCursor: String?

    // Posts grid (mirrors UserProfileViewModel so the shared grid/feed works)
    @Published var postFilter: PostFilter = .all
    @Published var posts: [CommunityPost] = []
    @Published var isLoadingPosts: Bool = false
    @Published var hasMorePosts: Bool = false
    private var postsCursor: String?
    private var hasLoadedPosts = false
    let canDeletePosts = true

    var filteredPosts: [CommunityPost] {
        switch postFilter {
        case .all: return posts
        case .workouts: return posts.filter { $0.workoutAttachment != nil }
        case .photos: return posts.filter { ($0.photoUrl?.isEmpty == false) }
        }
    }

    // MARK: - Properties

    private let networkService: NetworkServiceProtocol
    private let appDataState: AppDataState
    private let analyticsService: AnalyticsTrackingServiceProtocol
    private var hasLoaded = false
    private var cancellables = Set<AnyCancellable>()
    private var likeInFlight: Set<String> = []

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, appDataState: AppDataState, analyticsService: AnalyticsTrackingServiceProtocol) {
        self.networkService = networkService
        self.appDataState = appDataState
        self.analyticsService = analyticsService

        appDataState.$reloadVersion
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadProfile()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load If Needed

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadProfile()
    }

    // MARK: - Data Loading

    func loadProfile() async {
        analyticsService.track("profile_opened", properties: [:])
        isLoading = true
        errorMessage = nil

        do {
            profile = try await networkService.request(
                CommunityRouter.myProfile.endpoint,
                responseType: MyProfileResponse.self
            )
            expandCommentsForAllPosts()
            await loadAllComments()
        } catch {
            errorMessage = "Could not load profile."
        }

        isLoading = false
    }

    // MARK: - Workout History

    func loadWorkouts() async {
        guard !isLoadingWorkouts else { return }
        isLoadingWorkouts = true

        do {
            let response = try await networkService.request(
                CommunityRouter.myWorkouts(cursor: nil, limit: 10).endpoint,
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
                CommunityRouter.myWorkouts(cursor: cursor, limit: 10).endpoint,
                responseType: ProfileWorkoutsResponse.self
            )
            workouts.append(contentsOf: response.workouts)
            workoutCursor = response.nextCursor
            hasMoreWorkouts = response.hasMore
        } catch { }

        isLoadingWorkouts = false
    }

    // MARK: - Posts Grid

    func loadPostsIfNeeded() async {
        guard !hasLoadedPosts, let uid = profile?.user.id else { return }
        hasLoadedPosts = true
        await loadPosts(userId: uid)
    }

    private func loadPosts(userId: String) async {
        guard !isLoadingPosts else { return }
        isLoadingPosts = true
        do {
            let r = try await networkService.request(
                CommunityRouter.userPosts(userId: userId, cursor: nil, limit: 18).endpoint,
                responseType: ProfilePostsResponse.self
            )
            posts = r.posts
            postsCursor = r.nextCursor
            hasMorePosts = r.nextCursor != nil
        } catch { }
        isLoadingPosts = false
    }

    func loadMorePosts() async {
        guard hasMorePosts, !isLoadingPosts,
              let cursor = postsCursor, let uid = profile?.user.id else { return }
        isLoadingPosts = true
        do {
            let r = try await networkService.request(
                CommunityRouter.userPosts(userId: uid, cursor: cursor, limit: 18).endpoint,
                responseType: ProfilePostsResponse.self
            )
            posts.append(contentsOf: r.posts)
            postsCursor = r.nextCursor
            hasMorePosts = r.nextCursor != nil
        } catch { }
        isLoadingPosts = false
    }

    // MARK: - Post Interactions

    func toggleReaction(postId: String, emoji: String) {
        let key = "\(postId):\(emoji)"
        guard !likeInFlight.contains(key) else { return }
        likeInFlight.insert(key)

        // Optimistic update
        if let post = findPost(postId) {
            let reactions = optimisticToggle(post.reactions ?? [], emoji: emoji)
            applyPostUpdate(post.withReactions(reactions, reactionCount: reactions.reduce(0) { $0 + $1.count }))
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

    func deletePost(_ postId: String) async {
        do {
            _ = try await networkService.request(
                CommunityRouter.deletePost(postId: postId).endpoint,
                responseType: SuccessResponse.self
            )
            posts.removeAll { $0.id == postId }
            if let p = profile {
                profile = rebuild(p, recentPosts: p.recentPosts.filter { $0.id != postId })
            }
        } catch { }
    }

    // MARK: - Private Helpers

    /// Find a post across both the grid (`posts`) and the profile's recent list.
    private func findPost(_ id: String) -> CommunityPost? {
        posts.first { $0.id == id } ?? profile?.recentPosts.first { $0.id == id }
    }

    /// Write an updated post back to every array that holds it.
    private func applyPostUpdate(_ updated: CommunityPost) {
        if let i = posts.firstIndex(where: { $0.id == updated.id }) { posts[i] = updated }
        guard let p = profile,
              let i = p.recentPosts.firstIndex(where: { $0.id == updated.id }) else { return }
        var recent = p.recentPosts
        recent[i] = updated
        profile = rebuild(p, recentPosts: recent)
    }

    private func rebuild(_ p: MyProfileResponse, recentPosts: [CommunityPost]) -> MyProfileResponse {
        MyProfileResponse(
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
            recentPosts: recentPosts
        )
    }

    private func expandCommentsForAllPosts() {
        guard let posts = profile?.recentPosts else { return }
        for post in posts where post.commentCount > 0 {
            expandedComments.insert(post.id)
        }
    }

    private func loadAllComments() async {
        guard let posts = profile?.recentPosts else { return }
        await withTaskGroup(of: Void.self) { group in
            for post in posts where post.commentCount > 0 {
                group.addTask { [weak self] in
                    await self?.loadComments(postId: post.id)
                }
            }
        }
    }
}
