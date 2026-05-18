//
//  MockAuthService.swift
//  GymBroTests
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import AuthenticationServices
@testable import GymBro

/// Mock implementation of AuthServiceProtocol for testing
final class MockAuthService: AuthServiceProtocol {

    // MARK: - Mock Configuration

    var shouldFail = false
    var errorToThrow: AuthError = .unknownError

    // MARK: - Mock Data

    private var _mockUser: AuthUser?
    private var _mockOnboardingData: OnboardingData?
    private var _mockHasCompletedOnboarding: Bool = false
    private var authStateChangeHandler: ((AuthUser?) -> Void)?

    // MARK: - Tracking

    private(set) var signInWithAppleCallCount = 0
    private(set) var signInWithGoogleCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var deleteAccountCallCount = 0
    private(set) var restoreSessionCallCount = 0
    private(set) var refreshSessionCallCount = 0
    private(set) var observeAuthStateChangesCallCount = 0
    private(set) var saveOnboardingDataCallCount = 0
    private(set) var fetchOnboardingDataCallCount = 0

    // MARK: - Properties

    var currentUser: AuthUser? {
        get async {
            return _mockUser
        }
    }

    var isAuthenticated: Bool {
        get async {
            return _mockUser != nil
        }
    }

    var hasCompletedOnboarding: Bool {
        get async throws {
            if shouldFail {
                throw errorToThrow
            }
            return _mockHasCompletedOnboarding
        }
    }

    // MARK: - Authentication Methods

    func signInWithApple(_ authorization: ASAuthorization) async throws -> AuthUser {
        signInWithAppleCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        guard let user = _mockUser else {
            throw AuthError.invalidCredentials
        }

        return user
    }

    func signInWithGoogle(idToken: String, fullName: String?, avatarURL: String?) async throws -> AuthUser {
        signInWithGoogleCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        guard let user = _mockUser else {
            throw AuthError.invalidCredentials
        }

        return user
    }

    func signOut() async throws {
        signOutCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        _mockUser = nil
        _mockHasCompletedOnboarding = false
        authStateChangeHandler?(nil)
    }

    func deleteAccount() async throws {
        deleteAccountCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        _mockUser = nil
        _mockOnboardingData = nil
        _mockHasCompletedOnboarding = false
        authStateChangeHandler?(nil)
    }

    // MARK: - Session Management

    func restoreSession() async throws -> AuthUser? {
        restoreSessionCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        return _mockUser
    }

    func refreshSession() async throws {
        refreshSessionCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        // Nothing to do in mock
    }

    func observeAuthStateChanges(onChange: @escaping (AuthUser?) -> Void) {
        observeAuthStateChangesCallCount += 1
        authStateChangeHandler = onChange
    }

    // MARK: - Onboarding

    func saveOnboardingData(_ data: OnboardingData) async throws {
        saveOnboardingDataCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        _mockOnboardingData = data
        _mockHasCompletedOnboarding = true
    }

    func fetchOnboardingData() async throws -> OnboardingData? {
        fetchOnboardingDataCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        return _mockOnboardingData
    }

    // MARK: - Helper Methods

    /// Set mock user for testing
    func setMockUser(_ user: AuthUser?) {
        _mockUser = user
        authStateChangeHandler?(user)
    }

    /// Set mock onboarding data for testing
    func setMockOnboardingData(_ data: OnboardingData?) {
        _mockOnboardingData = data
        _mockHasCompletedOnboarding = data != nil
    }

    /// Set completion status
    func setMockHasCompletedOnboarding(_ completed: Bool) {
        _mockHasCompletedOnboarding = completed
    }

    /// Reset all mock state
    func reset() {
        _mockUser = nil
        _mockOnboardingData = nil
        _mockHasCompletedOnboarding = false
        authStateChangeHandler = nil

        signInWithAppleCallCount = 0
        signInWithGoogleCallCount = 0
        signOutCallCount = 0
        deleteAccountCallCount = 0
        restoreSessionCallCount = 0
        refreshSessionCallCount = 0
        observeAuthStateChangesCallCount = 0
        saveOnboardingDataCallCount = 0
        fetchOnboardingDataCallCount = 0

        shouldFail = false
        errorToThrow = .unknownError
    }
}
