//
//  AuthViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import Combine
import AuthenticationServices
import Supabase
import GoogleSignIn
import FirebaseAnalytics

/// ViewModel for managing authentication state and user sign-in/sign-out
@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentUser: AuthUser?
    @Published var hasCompletedOnboarding: Bool = false

    // MARK: - Dependencies

    private let authService: AuthServiceProtocol
    private let networkService: NetworkServiceProtocol

    // MARK: - Initialization

    init(authService: AuthServiceProtocol, networkService: NetworkServiceProtocol) {
        self.authService = authService
        self.networkService = networkService
    }

    // MARK: - Authentication Methods

    /// Sign in with Apple using ASAuthorization
    /// - Parameter authorization: ASAuthorization from Apple Sign-In flow
    func signInWithApple(_ authorization: ASAuthorization) async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signInWithApple(authorization)
            currentUser = user
            isAuthenticated = true
            Analytics.setUserID(user.id)
            trackSignIn(method: "apple", userId: user.id)
            await checkOnboardingStatus()
        } catch let error as AuthError {
            handleAuthError(error)
        } catch {
            errorMessage = "An unexpected error occurred during sign in"
        }

        isLoading = false
    }

    /// Sign in with Google — launches Google Sign-In SDK, then passes ID token to Supabase
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get the root view controller for presenting Google Sign-In
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                errorMessage = "Unable to find root view controller"
                isLoading = false
                return
            }

            // Launch Google Sign-In SDK
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get Google ID token"
                isLoading = false
                return
            }

            // Pass token to Supabase
            let session = try await SupabaseConfig.client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken)
            )

            let user = session.user
            let authUser = AuthUser(
                id: user.id.uuidString,
                email: user.email,
                fullName: result.user.profile?.name,
                avatarURL: result.user.profile?.imageURL(withDimension: 200)?.absoluteString,
                provider: .google,
                createdAt: user.createdAt
            )
            currentUser = authUser
            isAuthenticated = true
            Analytics.setUserID(authUser.id)
            trackSignIn(method: "google", userId: authUser.id)
            await checkOnboardingStatus()
        } catch let error as GIDSignInError where error.code == .canceled {
            errorMessage = nil // User cancelled
        } catch let error as AuthError {
            handleAuthError(error)
        } catch {
            errorMessage = "Google sign-in failed: \(error.localizedDescription)"
        }

        isLoading = false
    }
    
    /// Sign out current user
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authService.signOut()
            currentUser = nil
            isAuthenticated = false
            hasCompletedOnboarding = false
        } catch let error as AuthError {
            handleAuthError(error)
        } catch {
            errorMessage = "Failed to sign out"
        }

        isLoading = false
    }

    /// Check authentication status on app launch
    func checkAuthStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            if let user = try await authService.restoreSession() {
                currentUser = user
                isAuthenticated = true
                Analytics.setUserID(user.id)
                await checkOnboardingStatus()
            } else {
                isAuthenticated = false
                hasCompletedOnboarding = false
            }
        } catch {
            // Session restore failed, user needs to sign in again
            isAuthenticated = false
            hasCompletedOnboarding = false
            errorMessage = nil // Don't show error for failed restore
        }

        isLoading = false
    }

    /// Check if user has completed onboarding via API
    func checkOnboardingStatus() async {
        do {
            let response = try await networkService.request(AuthRouter.onboardingStatus.endpoint, responseType: OnboardingStatusResponse.self)
            hasCompletedOnboarding = response.hasCompletedOnboarding
            if response.hasCompletedOnboarding {
                await setOnboardingUserProperties()
            }
        } catch {
            // If API check fails, assume onboarding not completed
            hasCompletedOnboarding = false
        }
    }

    // MARK: - Error Handling

    /// Handle AuthError cases and set appropriate error messages
    private func handleAuthError(_ error: AuthError) {
        switch error {
        case .notAuthenticated:
            errorMessage = "You are not signed in"
            isAuthenticated = false
        case .invalidCredentials:
            errorMessage = "Invalid credentials provided"
        case .userCancelled:
            errorMessage = nil // Don't show error for user cancellation
        case .networkError(let underlyingError):
            errorMessage = "Network error: \(underlyingError.localizedDescription)"
        case .serverError(let message):
            errorMessage = "Server error: \(message)"
        case .unknownError:
            errorMessage = "An unknown error occurred"
        }
    }

    // MARK: - Helper Methods

    /// Clear any error messages
    func clearError() {
        errorMessage = nil
    }

    #if DEBUG
    /// Mock sign-in for development — creates a real Supabase session with valid tokens
    func mockSignIn() async {
        isLoading = true
        errorMessage = nil

        let email = "dev@gymbro.test"
        let password = "devdev123"
        let supabase = SupabaseConfig.client

        do {
            // Try sign-in first; if user doesn't exist, sign up then sign in
            let session: Session
            do {
                session = try await supabase.auth.signIn(email: email, password: password)
            } catch {
                _ = try await supabase.auth.signUp(email: email, password: password)
                session = try await supabase.auth.signIn(email: email, password: password)
            }

            let user = session.user
            currentUser = AuthUser(
                id: user.id.uuidString,
                email: user.email,
                fullName: "Dev User",
                avatarURL: nil,
                provider: .email,
                createdAt: user.createdAt
            )
            isAuthenticated = true
        } catch {
            errorMessage = "Mock sign-in failed: \(error.localizedDescription)"
        }

        isLoading = false
    }
    #endif

    // MARK: - Analytics Helpers

    private func trackSignIn(method: String, userId: String) {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "gym_bro_has_signed_in")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "gym_bro_has_signed_in")
            Analytics.logEvent(AnalyticsEventSignUp, parameters: [
                AnalyticsParameterMethod: method
            ])
        } else {
            Analytics.logEvent(AnalyticsEventLogin, parameters: [
                AnalyticsParameterMethod: method
            ])
        }
        Analytics.setUserProperty(method, forName: "auth_provider")
    }

    private func setOnboardingUserProperties() async {
        do {
            let data = try await networkService.request(
                OnboardingRouter.fetch.endpoint,
                responseType: OnboardingDataResponse.self
            )
            Analytics.setUserProperty(data.experienceLevel, forName: "experience_level")
            Analytics.setUserProperty(data.primaryGoals.joined(separator: ","), forName: "primary_goal")
            Analytics.setUserProperty("\(data.trainingFrequency)", forName: "training_frequency")
        } catch {
            // Non-critical — skip silently
        }
    }

    // MARK: - Response Models

    private struct OnboardingStatusResponse: Decodable {
        let hasCompletedOnboarding: Bool
    }

    private struct OnboardingDataResponse: Decodable {
        let experienceLevel: String
        let primaryGoals: [String]
        let trainingFrequency: Int
    }

    /// Setup auth state observer (optional, for real-time updates)
    func observeAuthState() {
        authService.observeAuthStateChanges { [weak self] user in
            Task { @MainActor [weak self] in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                if user != nil {
                    await self?.checkOnboardingStatus()
                } else {
                    self?.hasCompletedOnboarding = false
                }
            }
        }
    }
}
