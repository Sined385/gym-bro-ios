//
//  MyProfileViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-24.
//

import Foundation
import Combine

@MainActor
final class MyProfileViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var profile: MyProfileResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var expandedComments: Set<String> = []
    @Published var commentsMap: [String: [PostComment]] = [:]

    // MARK: - Properties

    private let networkService: NetworkServiceProtocol
    private let appDataState: AppDataState
    private var hasLoaded = false
    private var cancellables = Set<AnyCancellable>()
    private var likeInFlight: Set<String> = []

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, appDataState: AppDataState) {
        self.networkService = networkService
        self.appDataState = appDataState

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

    // MARK: - Post Interactions

    func toggleLike(postId: String) {
        guard !likeInFlight.contains(postId) else { return }
        likeInFlight.insert(postId)

        // Optimistic update
        if let index = profile?.recentPosts.firstIndex(where: { $0.id == postId }) {
            let post = profile!.recentPosts[index]
            let newIsLiked = !post.isLiked
            let newCount = newIsLiked ? post.likeCount + 1 : max(0, post.likeCount - 1)
            updatePost(at: index, likeCount: newCount, isLiked: newIsLiked)
        }

        Task {
            do {
                let response = try await networkService.request(
                    CommunityRouter.toggleLike(postId: postId).endpoint,
                    responseType: LikeResponse.self
                )
                if let index = profile?.recentPosts.firstIndex(where: { $0.id == postId }) {
                    updatePost(at: index, likeCount: response.likeCount, isLiked: response.isLiked)
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
                updatePost(at: index, commentCount: post.commentCount + 1)
            }
        } catch { }
    }

    func deletePost(_ postId: String) async {
        do {
            _ = try await networkService.request(
                CommunityRouter.deletePost(postId: postId).endpoint,
                responseType: SuccessResponse.self
            )
            guard var p = profile else { return }
            var posts = p.recentPosts
            posts.removeAll { $0.id == postId }
            profile = MyProfileResponse(
                user: p.user,
                primaryGoals: p.primaryGoals,
                experienceLevel: p.experienceLevel,
                bodyWeightKg: p.bodyWeightKg,
                memberSince: p.memberSince,
                consistencyStats: p.consistencyStats,
                extendedStats: p.extendedStats,
                followerCount: p.followerCount,
                followingCount: p.followingCount,
                recentPosts: posts
            )
        } catch { }
    }

    // MARK: - Private Helpers

    private func updatePost(at index: Int, likeCount: Int? = nil, isLiked: Bool? = nil, commentCount: Int? = nil) {
        guard let p = profile else { return }
        let post = p.recentPosts[index]
        let updated = CommunityPost(
            id: post.id,
            user: post.user,
            content: post.content,
            visibility: post.visibility,
            photoUrl: post.photoUrl,
            workoutAttachment: post.workoutAttachment,
            likeCount: likeCount ?? post.likeCount,
            commentCount: commentCount ?? post.commentCount,
            isLiked: isLiked ?? post.isLiked,
            isFollowingAuthor: post.isFollowingAuthor,
            isOwnPost: post.isOwnPost,
            createdAt: post.createdAt
        )
        var posts = p.recentPosts
        posts[index] = updated
        profile = MyProfileResponse(
            user: p.user,
            primaryGoals: p.primaryGoals,
            experienceLevel: p.experienceLevel,
            bodyWeightKg: p.bodyWeightKg,
            memberSince: p.memberSince,
            consistencyStats: p.consistencyStats,
            extendedStats: p.extendedStats,
            followerCount: p.followerCount,
            followingCount: p.followingCount,
            recentPosts: posts
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
