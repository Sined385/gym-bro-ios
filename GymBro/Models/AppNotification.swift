//
//  AppNotification.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-24.
//

import Foundation

struct AppNotification: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let body: String
    let data: NotificationData?
    let isRead: Bool
    let createdAt: String
}

struct NotificationData: Codable {
    let postId: String?
    let userId: String?
}

struct NotificationsResponse: Codable {
    let notifications: [AppNotification]
    let nextCursor: String?
    let hasMore: Bool
}

struct UnreadCountResponse: Codable {
    let count: Int
}

enum NotificationFilter: String, CaseIterable {
    case all
    case unread
}
