//
//  MockAuthService.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import AuthenticationServices

#if DEBUG
/// Mock implementation of AuthServiceProtocol for previews and testing
final class MockAuthService: AuthServiceProtocol {

    var mockUser: AuthUser?
    var mockOnboardingData: OnboardingData?
    var mockIsAuthenticated: Bool = false
    var mockHasCompletedOnboarding: Bool = false

    var currentUser: AuthUser? {
        get async {
            return mockUser
        }
    }

    var isAuthenticated: Bool {
        get async {
            return mockIsAuthenticated
        }
    }

    var hasCompletedOnboarding: Bool {
        get async throws {
            return mockHasCompletedOnboarding
        }
    }

    func signInWithApple(_ authorization: ASAuthorization) async throws -> AuthUser {
        let user = AuthUser(
            id: UUID().uuidString,
            email: "test@example.com",
            fullName: "Test User",
            avatarURL: nil,
            provider: .apple,
            createdAt: Date()
        )
        mockUser = user
        mockIsAuthenticated = true
        return user
    }

    func signInWithGoogle(idToken: String) async throws -> AuthUser {
        let user = AuthUser(
            id: UUID().uuidString,
            email: "test@example.com",
            fullName: "Test User",
            avatarURL: nil,
            provider: .google,
            createdAt: Date()
        )
        mockUser = user
        mockIsAuthenticated = true
        return user
    }

    func signOut() async throws {
        mockUser = nil
        mockIsAuthenticated = false
        mockHasCompletedOnboarding = false
    }

    func deleteAccount() async throws {
        mockUser = nil
        mockIsAuthenticated = false
        mockHasCompletedOnboarding = false
        mockOnboardingData = nil
    }

    func restoreSession() async throws -> AuthUser? {
        return mockUser
    }

    func refreshSession() async throws {
        // Mock implementation - do nothing
    }

    func observeAuthStateChanges(onChange: @escaping (AuthUser?) -> Void) {
        // Mock implementation - call once with current user
        onChange(mockUser)
    }

    func saveOnboardingData(_ data: OnboardingData) async throws {
        mockOnboardingData = data
        mockHasCompletedOnboarding = true
    }

    func fetchOnboardingData() async throws -> OnboardingData? {
        return mockOnboardingData
    }
}
#endif
