//
//  AppCoordinator.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine
import FirebaseAnalytics

/// Main app coordinator managing navigation flow based on auth and onboarding state
@MainActor
final class AppCoordinator: ObservableObject {

    // MARK: - Published Properties

    @Published var currentRoute: AppRoute = .loading

    // MARK: - Dependencies

    private let authViewModel: AuthViewModel

    // MARK: - Initialization

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    // MARK: - Route Determination

    /// Determines initial route on app launch
    func determineInitialRoute() async {
        // Check auth status first
        await authViewModel.checkAuthStatus()

        if authViewModel.isAuthenticated {
            // User is authenticated, check onboarding status
            await authViewModel.checkOnboardingStatus()

            if authViewModel.hasCompletedOnboarding {
                currentRoute = .home
            } else {
                currentRoute = .onboarding
            }
        } else {
            currentRoute = .authentication
        }
    }

    /// Navigate to specific route
    func navigate(to route: AppRoute) {
        currentRoute = route
    }

    /// Handle successful authentication
    func handleAuthenticationSuccess() async {
        await authViewModel.checkOnboardingStatus()

        if authViewModel.hasCompletedOnboarding {
            currentRoute = .home
        } else {
            currentRoute = .onboarding
        }
    }

    /// Handle successful onboarding completion
    func handleOnboardingCompletion() {
        Analytics.logEvent("onboarding_completed", parameters: nil)
        currentRoute = .buildingPlan
    }

    /// Handle sign out
    func handleSignOut() async {
        Analytics.setUserID(nil)
        await authViewModel.signOut()
        currentRoute = .authentication
    }
}

// MARK: - App Route

enum AppRoute: Equatable {
    case loading
    case authentication
    case onboarding
    case buildingPlan
    case home
}
