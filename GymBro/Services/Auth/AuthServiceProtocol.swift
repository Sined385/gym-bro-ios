//
//  AuthServiceProtocol.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import AuthenticationServices

/// Protocol defining authentication service capabilities
protocol AuthServiceProtocol: AnyObject {

    // MARK: - Properties

    /// Current authenticated user
    var currentUser: AuthUser? { get async }

    /// Whether user is currently authenticated
    var isAuthenticated: Bool { get async }

    /// Whether user has completed onboarding
    var hasCompletedOnboarding: Bool { get async throws }

    // MARK: - Authentication Methods

    /// Sign in with Apple using ASAuthorization
    /// - Parameter authorization: ASAuthorization from Apple Sign-In flow
    /// - Returns: Authenticated user
    func signInWithApple(_ authorization: ASAuthorization) async throws -> AuthUser

    /// Sign in with Google using ID token
    /// - Parameters:
    ///   - idToken: Google ID token from Google Sign-In SDK
    ///   - fullName: Optional profile name from the Google SDK (used to seed Supabase `user_metadata` when the ID token doesn't carry the name claim)
    ///   - avatarURL: Optional profile image URL from the Google SDK
    /// - Returns: Authenticated user
    func signInWithGoogle(idToken: String, fullName: String?, avatarURL: String?) async throws -> AuthUser

    /// Sign out current user
    func signOut() async throws

    /// Delete current user account
    func deleteAccount() async throws

    // MARK: - Session Management

    /// Restore session on app launch
    func restoreSession() async throws -> AuthUser?

    /// Refresh current session
    func refreshSession() async throws

    /// Listen to auth state changes
    func observeAuthStateChanges(onChange: @escaping (AuthUser?) -> Void)

    // MARK: - Onboarding

    /// Save onboarding data for current user
    /// - Parameter data: Onboarding data to save
    func saveOnboardingData(_ data: OnboardingData) async throws

    /// Fetch onboarding data for current user
    /// - Returns: Onboarding data if exists
    func fetchOnboardingData() async throws -> OnboardingData?
}

// MARK: - Auth User Model

/// Represents an authenticated user
struct AuthUser: Codable, Identifiable, Equatable {
    let id: String
    let email: String?
    let fullName: String?
    let avatarURL: String?
    let provider: AuthProvider
    let createdAt: Date

    enum AuthProvider: String, Codable {
        case apple
        case google
        case email
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case userCancelled
    case networkError(Error)
    case serverError(String)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .userCancelled:
            return "Sign in was cancelled"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
