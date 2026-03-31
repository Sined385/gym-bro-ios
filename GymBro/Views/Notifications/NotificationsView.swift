//
//  NotificationsView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-24.
//

import SwiftUI

struct NotificationsView: View {

    @StateObject private var viewModel: NotificationsViewModel = DependencyContainer.shared.resolve(NotificationsViewModel.self)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Custom Header
            header

            // MARK: - Filter
            filterBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // MARK: - Content
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                Spacer()
                ProgressView()
                    .tint(.gymBroPrimary)
                Spacer()
            } else if viewModel.notifications.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else if viewModel.filteredNotifications.isEmpty {
                Spacer()
                noUnreadState
                Spacer()
            } else {
                notificationList
            }
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .task {
            await viewModel.loadNotifications()
        }
        .analyticsScreen("Notifications")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Back button
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)

                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Text("\(viewModel.unreadCount) unread")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gymBroTextSecondary)
            }

            Spacer()

            if !viewModel.notifications.isEmpty {
                Button {
                    Task { await viewModel.markAllAsRead() }
                } label: {
                    Text("MARK ALL READ")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gymBroPrimary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 4) {
            filterPill(filter: .all, label: "All", badge: nil)
            filterPill(filter: .unread, label: "Unread", badge: viewModel.unreadCount)
        }
        .padding(4)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func filterPill(filter: NotificationFilter, label: String, badge: Int?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: viewModel.selectedFilter == filter ? .bold : .medium))
                    .foregroundColor(viewModel.selectedFilter == filter ? .white : Color(hex: "737373"))

                if let badge, badge > 0, viewModel.selectedFilter != filter {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.gymBroPrimary))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                viewModel.selectedFilter == filter
                    ? Color(hex: "2D3240")
                    : Color.clear
            )
            .cornerRadius(16)
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "737373"))

            Text("No notifications yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(hex: "737373"))
        }
    }

    private var noUnreadState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "30C08D"))

            Text("All caught up!")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(hex: "737373"))
        }
    }

    // MARK: - Notification List

    private var notificationList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredNotifications) { notification in
                    NotificationCard(notification: notification)
                        .onTapGesture {
                            Task { await viewModel.markAsRead(notification.id) }
                        }
                        .onAppear {
                            if notification.id == viewModel.filteredNotifications.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                }

                if viewModel.isLoading && !viewModel.notifications.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView().tint(.gymBroPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.loadNotifications()
        }
    }
}

// MARK: - Notification Card

private struct NotificationCard: View {
    let notification: AppNotification

    private var isSocial: Bool {
        ["like", "follow", "comment", "new_post"].contains(notification.type)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left icon
            if isSocial {
                socialAvatar
            } else {
                systemIcon
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                notificationText

                // Snippet bar for like/comment
                if notification.type == "like" || notification.type == "comment" {
                    snippetBar
                }

                // Timestamp
                Text(relativeTime)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "A1A1A1"))
            }

            Spacer(minLength: 4)

            // Unread dot
            if !notification.isRead {
                Circle()
                    .fill(Color.gymBroPrimary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            notification.isRead
                ? Color.white
                : Color.gymBroPrimary.opacity(0.02)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    notification.isRead
                        ? Color(hex: "F5F5F5")
                        : Color.gymBroPrimary.opacity(0.2),
                    lineWidth: 1
                )
        )
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Social Avatar with Badge

    private var socialAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            // Avatar circle
            if let userId = notification.data?.userId {
                AvatarView(
                    name: extractUserName(),
                    avatarUrl: nil,
                    size: 48
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            } else {
                AvatarView(
                    name: extractUserName(),
                    avatarUrl: nil,
                    size: 48
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            }

            // Type badge
            ZStack {
                Circle()
                    .fill(badgeBgColor)
                    .frame(width: 24, height: 24)

                Image(systemName: badgeIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(badgeIconColor)
            }
            .offset(x: 4, y: 4)
        }
    }

    // MARK: - System Icon

    private var systemIcon: some View {
        ZStack {
            Circle()
                .fill(systemIconBgColor)
                .frame(width: 48, height: 48)

            Image(systemName: systemIconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(systemIconFgColor)
        }
    }

    // MARK: - Notification Text

    private var notificationText: some View {
        let (name, action) = parseTitle()
        return (
            Text(name).font(.system(size: 15, weight: .bold)).foregroundColor(.gymBroNeutral900)
            + Text(" " + action).font(.system(size: 15, weight: .medium)).foregroundColor(.gymBroNeutral900)
        )
        .lineLimit(3)
    }

    // MARK: - Snippet Bar

    private var snippetBar: some View {
        Text(notification.body)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.gymBroTextSecondary)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "FAFAFA"))
            .cornerRadius(12)
    }

    // MARK: - Parse Title

    private func parseTitle() -> (name: String, action: String) {
        let title = notification.title
        let actionVerbs = ["liked", "commented", "started following", "shared"]

        for verb in actionVerbs {
            if let range = title.range(of: verb) {
                let name = String(title[title.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let action = String(title[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
                return (name, action)
            }
        }

        // Fallback: entire title as action (for system notifications)
        return ("", title)
    }

    private func extractUserName() -> String {
        let (name, _) = parseTitle()
        return name.isEmpty ? "U" : name
    }

    // MARK: - Badge Styling

    private var badgeBgColor: Color {
        switch notification.type {
        case "follow": return Color(red: 48/255, green: 192/255, blue: 141/255, opacity: 0.1)
        case "like": return Color(red: 232/255, green: 106/255, blue: 117/255, opacity: 0.1)
        case "comment": return Color(red: 45/255, green: 50/255, blue: 64/255, opacity: 0.1)
        case "new_post": return Color(red: 48/255, green: 192/255, blue: 141/255, opacity: 0.1)
        default: return Color(hex: "F5F5F5")
        }
    }

    private var badgeIcon: String {
        switch notification.type {
        case "follow": return "person.fill"
        case "like": return "heart.fill"
        case "comment": return "bubble.left.fill"
        case "new_post": return "doc.text.fill"
        default: return "bell.fill"
        }
    }

    private var badgeIconColor: Color {
        switch notification.type {
        case "follow": return Color(hex: "30C08D")
        case "like": return .gymBroPrimary
        case "comment": return Color(hex: "2D3240")
        case "new_post": return Color(hex: "30C08D")
        default: return .gymBroNeutral900
        }
    }

    // MARK: - System Icon Styling

    private var systemIconBgColor: Color {
        switch notification.type {
        case "workout_skip", "streak": return Color(red: 245/255, green: 166/255, blue: 35/255, opacity: 0.1)
        case "d2_engagement": return Color(red: 122/255, green: 130/255, blue: 246/255, opacity: 0.1)
        default: return Color(hex: "F5F5F5")
        }
    }

    private var systemIconName: String {
        switch notification.type {
        case "workout_skip": return "figure.run"
        case "streak": return "flame.fill"
        case "d2_engagement": return "sparkles"
        default: return "bell.fill"
        }
    }

    private var systemIconFgColor: Color {
        switch notification.type {
        case "workout_skip", "streak": return Color(hex: "F5A623")
        case "d2_engagement": return Color(red: 122/255, green: 130/255, blue: 246/255)
        default: return .gymBroNeutral900
        }
    }

    // MARK: - Relative Time

    private var relativeTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: notification.createdAt) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: notification.createdAt) else {
                return ""
            }
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }

        let relativeFmt = RelativeDateTimeFormatter()
        relativeFmt.unitsStyle = .abbreviated
        return relativeFmt.localizedString(for: date, relativeTo: Date())
    }
}
