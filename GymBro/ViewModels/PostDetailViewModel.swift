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
    private var reactionInFlight: Set<String> = []
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
                post = p.withCommentCount(p.commentCount + 1)
            }
        } catch { }
    }

    // MARK: - Reaction

    func toggleReaction(emoji: String) {
        let key = emoji
        guard !reactionInFlight.contains(key), let p = post else { return }
        reactionInFlight.insert(key)

        // Optimistic update
        var reactions = p.reactions ?? []
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
            }
        } else {
            reactions.append(PostReaction(emoji: emoji, count: 1, isReacted: true))
        }
        let totalCount = reactions.reduce(0) { $0 + $1.count }
        post = p.withReactions(reactions, reactionCount: totalCount)

        Task {
            do {
                let response = try await networkService.request(
                    CommunityRouter.toggleReaction(postId: postId, emoji: emoji).endpoint,
                    responseType: ReactionResponse.self
                )
                if let current = post {
                    post = current.withReactions(response.reactions, reactionCount: response.totalReactionCount)
                }
            } catch { }
            reactionInFlight.remove(key)
        }
    }

    // MARK: - Follow

    func toggleFollow() {
        guard !followInFlight, let p = post, !p.isOwnPost else { return }
        followInFlight = true

        let wasFollowing = p.isFollowingAuthor
        post = p.withFollowing(!wasFollowing)

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
                if let current = post {
                    post = current.withFollowing(wasFollowing)
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

    // MARK: - Block

    func blockUser(userId: String) async {
        let _ = try? await networkService.request(
            CommunityRouter.blockUser(userId: userId).endpoint,
            responseType: SuccessResponse.self
        )
    }

}
