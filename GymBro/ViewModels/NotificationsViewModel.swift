//
//  NotificationsViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-24.
//

import Foundation
import Combine

@MainActor
final class NotificationsViewModel: ObservableObject {

    // MARK: - Published

    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    @Published var hasMore = false
    @Published var selectedFilter: NotificationFilter = .all

    var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all:
            return notifications
        case .unread:
            return notifications.filter { !$0.isRead }
        }
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    // MARK: - Private

    private let networkService: NetworkServiceProtocol
    private let pushService: PushNotificationService
    private var nextCursor: String?

    // MARK: - Init

    init(networkService: NetworkServiceProtocol, pushService: PushNotificationService) {
        self.networkService = networkService
        self.pushService = pushService
    }

    // MARK: - Load

    func loadNotifications() async {
        guard !isLoading else { return }
        isLoading = true
        nextCursor = nil

        do {
            let response = try await networkService.request(
                NotificationRouter.list(cursor: nil, limit: 20).endpoint,
                responseType: NotificationsResponse.self
            )
            notifications = response.notifications
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            // Silently fail
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading, let cursor = nextCursor else { return }
        isLoading = true

        do {
            let response = try await networkService.request(
                NotificationRouter.list(cursor: cursor, limit: 20).endpoint,
                responseType: NotificationsResponse.self
            )
            notifications.append(contentsOf: response.notifications)
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            // Silently fail
        }

        isLoading = false
    }

    // MARK: - Mark Read

    func markAsRead(_ id: String) async {
        // Optimistic update
        if let idx = notifications.firstIndex(where: { $0.id == id && !$0.isRead }) {
            let old = notifications[idx]
            notifications[idx] = AppNotification(
                id: old.id, type: old.type, title: old.title,
                body: old.body, data: old.data, isRead: true, createdAt: old.createdAt
            )
            pushService.unreadCount = max(0, pushService.unreadCount - 1)
            pushService.updateBadge()
        }

        do {
            try await networkService.request(
                NotificationRouter.markRead(notificationId: id).endpoint
            )
        } catch {
            // Revert would be complex; just refresh on next load
        }
    }

    func markAllAsRead() async {
        // Optimistic update
        notifications = notifications.map { n in
            AppNotification(
                id: n.id, type: n.type, title: n.title,
                body: n.body, data: n.data, isRead: true, createdAt: n.createdAt
            )
        }
        pushService.unreadCount = 0
        pushService.updateBadge()

        do {
            try await networkService.request(
                NotificationRouter.markAllRead.endpoint
            )
        } catch {
            // Best-effort
        }
    }
}
