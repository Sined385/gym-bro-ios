//
//  PostDetailViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-03.
//

import Foundation
import Combine

@MainActor
final class PostDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var post: CommunityPost?
    @Published var comments: [PostComment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Properties

    let postId: String
    private let networkService: NetworkServiceProtocol
    private var likeInFlight = false
    private var followInFlight = false

    // MARK: - Initialization

    init(postId: String, networkService: NetworkServiceProtocol) {
        self.postId = postId
        self.networkService = networkService
    }

    // MARK: - Load Post

    func loadPost() async {
        isLoading = true
        errorMessage = nil

        do {
            post = try await networkService.request(
                CommunityRouter.getPost(postId: postId).endpoint,
                responseType: CommunityPost.self
            )
            await loadComments()
        } catch {
            errorMessage = "Could not load post."
        }

        isLoading = false
    }

    // MARK: - Comments

    func loadComments() async {
        do {
            let response = try await networkService.request(
                CommunityRouter.getComments(postId: postId, cursor: nil, limit: 50).endpoint,
                responseType: CommentsResponse.self
            )
            comments = response.comments
        } catch {
            comments = []
        }
    }

    func addComment(content: String) async {
        do {
            let comment = try await networkService.request(
                CommunityRouter.createComment(postId: postId, content: content).endpoint,
                responseType: PostComment.self
            )
            comments.insert(comment, at: 0)
            if let p = post {
                post = CommunityPost(
                    id: p.id,
                    user: p.user,
                    content: p.content,
                    visibility: p.visibility,
                    photoUrl: p.photoUrl,
                    workoutAttachment: p.workoutAttachment,
                    likeCount: p.likeCount,
                    commentCount: p.commentCount + 1,
                    isLiked: p.isLiked,
                    isFollowingAuthor: p.isFollowingAuthor,
                    isOwnPost: p.isOwnPost,
                    createdAt: p.createdAt
                )
            }
        } catch { }
    }

    // MARK: - Like

    func toggleLike() {
        guard !likeInFlight, let p = post else { return }
        likeInFlight = true

        let newIsLiked = !p.isLiked
        let newCount = newIsLiked ? p.likeCount + 1 : max(0, p.likeCount - 1)
        post = CommunityPost(
            id: p.id,
            user: p.user,
            content: p.content,
            visibility: p.visibility,
            photoUrl: p.photoUrl,
            workoutAttachment: p.workoutAttachment,
            likeCount: newCount,
            commentCount: p.commentCount,
            isLiked: newIsLiked,
            isFollowingAuthor: p.isFollowingAuthor,
            isOwnPost: p.isOwnPost,
            createdAt: p.createdAt
        )

        Task {
            do {
                let response = try await networkService.request(
                    CommunityRouter.toggleLike(postId: postId).endpoint,
                    responseType: LikeResponse.self
                )
                if let current = post {
                    post = CommunityPost(
                        id: current.id,
                        user: current.user,
                        content: current.content,
                        visibility: current.visibility,
                        photoUrl: current.photoUrl,
                        workoutAttachment: current.workoutAttachment,
                        likeCount: response.likeCount,
                        commentCount: current.commentCount,
                        isLiked: response.isLiked,
                        isFollowingAuthor: current.isFollowingAuthor,
                        isOwnPost: current.isOwnPost,
                        createdAt: current.createdAt
                    )
                }
            } catch { }
            likeInFlight = false
        }
    }

    // MARK: - Follow

    func toggleFollow() {
        guard !followInFlight, let p = post, !p.isOwnPost else { return }
        followInFlight = true

        let wasFollowing = p.isFollowingAuthor
        post = CommunityPost(
            id: p.id,
            user: p.user,
            content: p.content,
            visibility: p.visibility,
            photoUrl: p.photoUrl,
            workoutAttachment: p.workoutAttachment,
            likeCount: p.likeCount,
            commentCount: p.commentCount,
            isLiked: p.isLiked,
            isFollowingAuthor: !wasFollowing,
            isOwnPost: p.isOwnPost,
            createdAt: p.createdAt
        )

        Task {
            do {
                if wasFollowing {
                    _ = try await networkService.request(
                        CommunityRouter.unfollowUser(userId: p.user.id).endpoint,
                        responseType: SuccessResponse.self
                    )
                } else {
                    _ = try await networkService.request(
                        CommunityRouter.followUser(userId: p.user.id).endpoint,
                        responseType: FollowResponse.self
                    )
                }
            } catch {
                // Revert
                if let current = post {
                    post = CommunityPost(
                        id: current.id,
                        user: current.user,
                        content: current.content,
                        visibility: current.visibility,
                        photoUrl: current.photoUrl,
                        workoutAttachment: current.workoutAttachment,
                        likeCount: current.likeCount,
                        commentCount: current.commentCount,
                        isLiked: current.isLiked,
                        isFollowingAuthor: wasFollowing,
                        isOwnPost: current.isOwnPost,
                        createdAt: current.createdAt
                    )
                }
            }
            followInFlight = false
        }
    }

    // MARK: - Delete

    func deletePost() async -> Bool {
        do {
            _ = try await networkService.request(
                CommunityRouter.deletePost(postId: postId).endpoint,
                responseType: SuccessResponse.self
            )
            return true
        } catch {
            return false
        }
    }

}
