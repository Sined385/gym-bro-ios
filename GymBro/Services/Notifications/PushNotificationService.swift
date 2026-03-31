//
//  PushNotificationService.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-24.
//

import UIKit
import Combine
import UserNotifications

@MainActor
final class PushNotificationService: ObservableObject {

    // MARK: - Published

    @Published var unreadCount: Int = 0

    // MARK: - Private

    private let networkService: NetworkServiceProtocol
    private var currentToken: String?
    private var tokenRegistered = false

    // MARK: - Init

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Token Management

    func registerToken(_ token: String) async {
        currentToken = token
        tokenRegistered = false
        await sendTokenToServer()
    }

    /// Retry sending the cached FCM token to the backend.
    /// Call this after the user logs in so the token is registered with auth.
    func reregisterTokenIfNeeded() async {
        guard currentToken != nil, !tokenRegistered else { return }
        await sendTokenToServer()
    }

    private func sendTokenToServer() async {
        guard let token = currentToken else { return }
        do {
            try await networkService.request(
                NotificationRouter.registerToken(token: token, platform: "ios").endpoint
            )
            tokenRegistered = true
        } catch {
            // Token registration failed — will retry after next login or FCM refresh
        }
    }

    func removeToken() async {
        guard let token = currentToken else { return }
        do {
            try await networkService.request(
                NotificationRouter.removeToken(token: token).endpoint
            )
        } catch {
            // Best-effort cleanup
        }
        currentToken = nil
    }

    // MARK: - Unread Count

    func fetchUnreadCount() async {
        do {
            let response = try await networkService.request(
                NotificationRouter.unreadCount.endpoint,
                responseType: UnreadCountResponse.self
            )
            unreadCount = response.count
            updateBadge()
        } catch {
            // Silently fail
        }
    }

    // MARK: - Badge

    func updateBadge() {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(unreadCount)
        }
    }
}
