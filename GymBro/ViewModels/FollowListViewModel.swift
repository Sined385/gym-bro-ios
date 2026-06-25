//
//  FollowListViewModel.swift
//  GymBro
//

import Foundation
import Combine

@MainActor
final class FollowListViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedTab: FollowListTab
    @Published var followers: [FollowListUser] = []
    @Published var following: [FollowListUser] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false

    // MARK: - Pagination

    private var followersCursor: String?
    private var followersHasMore: Bool = true
    private var followingCursor: String?
    private var followingHasMore: Bool = true

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let analyticsService: AnalyticsTrackingServiceProtocol
    /// nil = the current user's own lists; non-nil = another user's profile.
    private let targetUserId: String?
    private var followInFlight: Set<String> = []
    private var hasLoadedFollowers = false
    private var hasLoadedFollowing = false

    // MARK: - Initialization

    init(
        initialTab: FollowListTab,
        userId: String? = nil,
        networkService: NetworkServiceProtocol,
        analyticsService: AnalyticsTrackingServiceProtocol
    ) {
        self.selectedTab = initialTab
        self.targetUserId = userId
        self.networkService = networkService
        self.analyticsService = analyticsService
    }

    // MARK: - Endpoints

    private func followersEndpoint(cursor: String?) -> APIEndpoint {
        if let targetUserId {
            return CommunityRouter.userFollowers(userId: targetUserId, cursor: cursor, limit: 20).endpoint
        }
        return CommunityRouter.myFollowers(cursor: cursor, limit: 20).endpoint
    }

    private func followingEndpoint(cursor: String?) -> APIEndpoint {
        if let targetUserId {
            return CommunityRouter.userFollowing(userId: targetUserId, cursor: cursor, limit: 20).endpoint
        }
        return CommunityRouter.myFollowing(cursor: cursor, limit: 20).endpoint
    }

    // MARK: - Loading

    func loadInitial() async {
        if selectedTab == .followers {
            await loadFollowers()
        } else {
            await loadFollowing()
        }
    }

    func onTabChanged() async {
        if selectedTab == .followers && !hasLoadedFollowers {
            await loadFollowers()
        } else if selectedTab == .following && !hasLoadedFollowing {
            await loadFollowing()
        }
    }

    func loadFollowers() async {
        isLoading = true
        followersCursor = nil
        followersHasMore = true

        do {
            let response = try await networkService.request(
                followersEndpoint(cursor: nil),
                responseType: FollowListResponse.self
            )
            followers = response.users
            followersCursor = response.nextCursor
            followersHasMore = response.hasMore
            hasLoadedFollowers = true
        } catch {
            // Silently fail
        }

        isLoading = false
    }

    func loadFollowing() async {
        isLoading = true
        followingCursor = nil
        followingHasMore = true

        do {
            let response = try await networkService.request(
                followingEndpoint(cursor: nil),
                responseType: FollowListResponse.self
            )
            following = response.users
            followingCursor = response.nextCursor
            followingHasMore = response.hasMore
            hasLoadedFollowing = true
        } catch {
            // Silently fail
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore else { return }

        if selectedTab == .followers {
            guard followersHasMore, followersCursor != nil else { return }
            isLoadingMore = true
            do {
                let response = try await networkService.request(
                    followersEndpoint(cursor: followersCursor),
                    responseType: FollowListResponse.self
                )
                followers.append(contentsOf: response.users)
                followersCursor = response.nextCursor
                followersHasMore = response.hasMore
            } catch {}
            isLoadingMore = false
        } else {
            guard followingHasMore, followingCursor != nil else { return }
            isLoadingMore = true
            do {
                let response = try await networkService.request(
                    followingEndpoint(cursor: followingCursor),
                    responseType: FollowListResponse.self
                )
                following.append(contentsOf: response.users)
                followingCursor = response.nextCursor
                followingHasMore = response.hasMore
            } catch {}
            isLoadingMore = false
        }
    }

    // MARK: - Follow Toggle

    func toggleFollow(userId: String) {
        guard !followInFlight.contains(userId) else { return }
        followInFlight.insert(userId)

        if selectedTab == .followers {
            // Toggle isFollowing on the follower
            guard let index = followers.firstIndex(where: { $0.id == userId }) else {
                followInFlight.remove(userId)
                return
            }
            let wasFollowing = followers[index].isFollowing
            followers[index].isFollowing = !wasFollowing

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
                    // Revert
                    if let idx = followers.firstIndex(where: { $0.id == userId }) {
                        followers[idx].isFollowing = wasFollowing
                    }
                }
                followInFlight.remove(userId)
            }
        } else {
            // Unfollow from Following tab — remove from list
            guard let index = following.firstIndex(where: { $0.id == userId }) else {
                followInFlight.remove(userId)
                return
            }
            let removed = following.remove(at: index)

            Task {
                do {
                    _ = try await networkService.request(
                        CommunityRouter.unfollowUser(userId: userId).endpoint,
                        responseType: SuccessResponse.self
                    )
                } catch {
                    // Revert — re-insert
                    let insertIndex = min(index, following.count)
                    following.insert(removed, at: insertIndex)
                }
                followInFlight.remove(userId)
            }
        }
    }
}
