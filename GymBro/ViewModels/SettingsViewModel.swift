//
//  SettingsViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-25.
//

import Foundation
import Combine
import UserNotifications

/// Response model for GET /api/v1/onboarding.
/// Property names are camelCase because NetworkService's decoder uses
/// `.convertFromSnakeCase` — JSON `ai_coach_context` arrives as `aiCoachContext`.
private struct OnboardingResponse: Decodable {
    let preferredRestTime: Int?
    let aiCoachContext: String?
}

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Constants

    static let restTimeKey = "preferred_rest_time_seconds"

    // MARK: - Published

    @Published var pushNotificationsEnabled: Bool = false
    @Published var shareProgressData: Bool = true
    @Published var preferredRestTime: RestTime = .ninety
    @Published var aiCoachContext: String = ""
    @Published var aiCoachContextUpdatedAt: Date?
    @Published var isLoggingOut: Bool = false
    @Published var showDeleteConfirmation: Bool = false

    // MARK: - Dependencies

    private let authService: AuthServiceProtocol
    private let networkService: NetworkServiceProtocol
    private let pushService: PushNotificationService

    // MARK: - Init

    init(authService: AuthServiceProtocol, networkService: NetworkServiceProtocol, pushService: PushNotificationService) {
        self.authService = authService
        self.networkService = networkService
        self.pushService = pushService

        // Load from UserDefaults immediately
        let stored = UserDefaults.standard.integer(forKey: Self.restTimeKey)
        if stored > 0, let restTime = RestTime(rawValue: stored) {
            self.preferredRestTime = restTime
        }
    }

    // MARK: - Load Settings

    func loadSettings() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        pushNotificationsEnabled = settings.authorizationStatus == .authorized

        // Sync rest time from backend
        do {
            let response: OnboardingResponse = try await networkService.request(
                OnboardingRouter.fetch.endpoint,
                responseType: OnboardingResponse.self
            )
            if let seconds = response.preferredRestTime,
               let restTime = RestTime(rawValue: seconds) {
                preferredRestTime = restTime
                UserDefaults.standard.set(seconds, forKey: Self.restTimeKey)
            }
            aiCoachContext = response.aiCoachContext ?? ""
        } catch {
            // Keep UserDefaults / default value
        }
    }

    // MARK: - Update AI Coach Context

    /// Saves the AI coach context note to the backend. Empty string clears
    /// the field server-side (the API treats "" as "null this column").
    func updateAiCoachContext(_ context: String) async {
        aiCoachContext = context
        do {
            try await networkService.request(
                OnboardingRouter.updateAiCoachContext(context: context).endpoint
            )
            aiCoachContextUpdatedAt = Date()
        } catch {
            print("[Settings] Failed to save AI coach context: \(error)")
        }
    }

    // MARK: - Update Rest Time

    func updateRestTime(_ restTime: RestTime) {
        preferredRestTime = restTime
        UserDefaults.standard.set(restTime.rawValue, forKey: Self.restTimeKey)
        Task {
            do {
                try await networkService.request(
                    OnboardingRouter.updateRestTime(seconds: restTime.rawValue).endpoint
                )
            } catch {
                print("[Settings] Failed to save rest time: \(error)")
            }
        }
    }

    // MARK: - Toggle Push Notifications

    func togglePushNotifications(enabled: Bool) async {
        if enabled {
            let granted = await pushService.requestPermission()
            pushNotificationsEnabled = granted
        } else {
            await pushService.removeToken()
            pushNotificationsEnabled = false
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoggingOut = true
        await pushService.removeToken()
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        await pushService.removeToken()
        try await authService.deleteAccount()
    }
}
