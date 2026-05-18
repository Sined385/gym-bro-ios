//
//  SupabaseAuthService.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import AuthenticationServices
import Supabase

/// Supabase implementation of AuthServiceProtocol
final class SupabaseAuthService: AuthServiceProtocol {

    // MARK: - Properties

    private let supabase = SupabaseConfig.client
    private var authStateTask: Task<Void, Never>?
    private var cachedUser: AuthUser?

    // MARK: - AuthServiceProtocol Properties

    var currentUser: AuthUser? {
        get async {
            if let cached = cachedUser {
                return cached
            }

            // Try to fetch from session
            do {
                let session = try await supabase.auth.session
                let user = convertToAuthUser(from: session.user)
                cachedUser = user
                return user
            } catch {
                return nil
            }
        }
    }

    var isAuthenticated: Bool {
        get async {
            return await currentUser != nil
        }
    }

    var hasCompletedOnboarding: Bool {
        get async throws {
            guard await isAuthenticated else {
                return false
            }

            let data = try await fetchOnboardingData()
            return data != nil && data?.isComplete == true
        }
    }

    // MARK: - Initialization

    init() {
        // Initialize with cached session if available
        Task {
            _ = try? await restoreSession()
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Authentication Methods

    func signInWithApple(_ authorization: ASAuthorization) async throws -> AuthUser {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }

        // Apple only sends fullName/email on the FIRST sign-in via the credential.
        // The ID token typically lacks a name claim, so capture them here and
        // persist into Supabase user_metadata so future restores get the name too.
        let appleFullName = appleIDCredential.fullName.flatMap { components -> String? in
            let formatted = PersonNameComponentsFormatter().string(from: components)
            return formatted.isEmpty ? nil : formatted
        }

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: tokenString
                )
            )

            let enrichedUser = try await enrichUserMetadataIfNeeded(
                sessionUser: session.user,
                fullName: appleFullName,
                avatarURL: nil
            )

            let authUser = convertToAuthUser(from: enrichedUser)
            cachedUser = authUser
            return authUser

        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }

    func signInWithGoogle(idToken: String, fullName: String?, avatarURL: String?) async throws -> AuthUser {
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken
                )
            )

            let enrichedUser = try await enrichUserMetadataIfNeeded(
                sessionUser: session.user,
                fullName: fullName,
                avatarURL: avatarURL
            )

            let authUser = convertToAuthUser(from: enrichedUser)
            cachedUser = authUser
            return authUser

        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }

    /// Fills in `full_name` / `avatar_url` on the Supabase auth user when the IdP
    /// session arrived without them. Returns the (possibly updated) `User`.
    private func enrichUserMetadataIfNeeded(
        sessionUser: User,
        fullName: String?,
        avatarURL: String?
    ) async throws -> User {
        var patch: [String: AnyJSON] = [:]
        if let name = fullName, !name.isEmpty,
           metadataString(sessionUser.userMetadata["full_name"]).map(\.isEmpty) ?? true {
            patch["full_name"] = .string(name)
        }
        if let url = avatarURL, !url.isEmpty,
           metadataString(sessionUser.userMetadata["avatar_url"]).map(\.isEmpty) ?? true {
            patch["avatar_url"] = .string(url)
        }

        guard !patch.isEmpty else { return sessionUser }

        do {
            return try await supabase.auth.update(user: UserAttributes(data: patch))
        } catch {
            // Metadata enrichment is best-effort — never block sign-in on it.
            return sessionUser
        }
    }

    private func metadataString(_ value: AnyJSON?) -> String? {
        guard let value, case let .string(s) = value else { return nil }
        return s
    }

    func signOut() async throws {
        do {
            try await supabase.auth.signOut()
            cachedUser = nil
        } catch {
            throw AuthError.networkError(error)
        }
    }

    func deleteAccount() async throws {
        guard let user = await currentUser else {
            throw AuthError.notAuthenticated
        }

        do {
            // Delete user data from database first
            try await supabase
                .from("onboarding_data")
                .delete()
                .eq("user_id", value: user.id)
                .execute()

            // Delete auth user
            // Note: This requires admin privileges or a custom RPC function
            // For now, we'll sign out - actual deletion should be done via Supabase admin API
            try await signOut()

        } catch {
            throw AuthError.serverError("Failed to delete account: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Management

    func restoreSession() async throws -> AuthUser? {
        do {
            let session = try await supabase.auth.session
            let user = convertToAuthUser(from: session.user)
            cachedUser = user
            return user

        } catch {
            // Session doesn't exist or is invalid
            return nil
        }
    }

    func refreshSession() async throws {
        do {
            let session = try await supabase.auth.refreshSession()
            let user = convertToAuthUser(from: session.user)
            cachedUser = user
        } catch {
            throw AuthError.networkError(error)
        }
    }

    func observeAuthStateChanges(onChange: @escaping (AuthUser?) -> Void) {
        // Cancel existing task
        authStateTask?.cancel()

        // Create new observation task
        authStateTask = Task {
            for await state in await supabase.auth.authStateChanges {
                guard !Task.isCancelled else { break }

                switch state.event {
                case .signedIn, .tokenRefreshed:
                    if let session = state.session {
                        let user = convertToAuthUser(from: session.user)
                        cachedUser = user
                        onChange(user)
                    }

                case .signedOut:
                    cachedUser = nil
                    onChange(nil)

                case .initialSession:
                    if let session = state.session {
                        let user = convertToAuthUser(from: session.user)
                        cachedUser = user
                        onChange(user)
                    } else {
                        onChange(nil)
                    }

                case .userDeleted:
                    cachedUser = nil
                    onChange(nil)

                default:
                    break
                }
            }
        }
    }

    // MARK: - Onboarding

    func saveOnboardingData(_ data: OnboardingData) async throws {
        guard let user = await currentUser else {
            throw AuthError.notAuthenticated
        }

        // Create database DTO
        let dbData = OnboardingDataDTO(
            userId: user.id,
            primaryGoals: data.primaryGoals.map { $0.rawValue },
            primarySports: data.primarySports,
            experienceLevel: data.experienceLevel?.rawValue,
            trainingFrequency: data.trainingFrequency?.days,
            workoutDuration: data.workoutDuration?.minutes,
            availableEquipment: data.availableEquipment?.rawValue,
            injuries: data.injuries.map { injury in
                if case .custom(let text) = injury {
                    return ["type": "custom", "value": text]
                } else {
                    return ["type": injury.rawValue, "value": injury.displayName]
                }
            },
            completedAt: data.completedAt,
            updatedAt: Date()
        )

        do {
            // Upsert: insert or update if exists
            try await supabase
                .from("onboarding_data")
                .upsert(dbData)
                .execute()

        } catch {
            throw AuthError.serverError("Failed to save onboarding data: \(error.localizedDescription)")
        }
    }

    func fetchOnboardingData() async throws -> OnboardingData? {
        guard let user = await currentUser else {
            throw AuthError.notAuthenticated
        }

        do {
            let response: OnboardingDataDTO = try await supabase
                .from("onboarding_data")
                .select()
                .eq("user_id", value: user.id)
                .single()
                .execute()
                .value

            return response.toOnboardingData()

        } catch {
            // If no data found, return nil instead of throwing
            if error.localizedDescription.contains("PGRST116") ||
               error.localizedDescription.contains("No rows") {
                return nil
            }
            throw AuthError.serverError("Failed to fetch onboarding data: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    private func convertToAuthUser(from user: User) -> AuthUser {
        // Determine provider from app metadata
        let provider: AuthUser.AuthProvider
        if let providerValue = user.appMetadata["provider"],
           case let .string(providerString) = providerValue {
            switch providerString {
            case "apple":
                provider = .apple
            case "google":
                provider = .google
            default:
                provider = .email
            }
        } else {
            provider = .email
        }

        // Extract user metadata
        var fullName: String?
        if let nameValue = user.userMetadata["full_name"],
           case let .string(name) = nameValue {
            fullName = name
        }

        var avatarURL: String?
        if let urlValue = user.userMetadata["avatar_url"],
           case let .string(url) = urlValue {
            avatarURL = url
        }

        return AuthUser(
            id: user.id.uuidString,
            email: user.email,
            fullName: fullName,
            avatarURL: avatarURL,
            provider: provider,
            createdAt: user.createdAt
        )
    }

}

// MARK: - Database DTO

/// Data Transfer Object for Supabase onboarding_data table
private struct OnboardingDataDTO: Codable {
    let userId: String
    let primaryGoals: [String]?
    let primarySports: [String]?
    let experienceLevel: String?
    let trainingFrequency: Int?
    let workoutDuration: Int?
    let availableEquipment: String?
    let injuries: [[String: String]]
    let completedAt: Date?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case primaryGoals = "primary_goals"
        case primarySports = "primary_sports"
        case experienceLevel = "experience_level"
        case trainingFrequency = "training_frequency"
        case workoutDuration = "workout_duration"
        case availableEquipment = "available_equipment"
        case injuries
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
    }

    func toOnboardingData() -> OnboardingData {
        var data = OnboardingData()

        if let goals = primaryGoals {
            data.primaryGoals = goals.compactMap { PrimaryGoal(rawValue: $0) }
        }
        if let sports = primarySports {
            data.primarySports = sports
        }

        if let levelString = experienceLevel {
            data.experienceLevel = ExperienceLevel(rawValue: levelString)
        }

        if let frequency = trainingFrequency {
            data.trainingFrequency = TrainingFrequency(rawValue: frequency)
        }

        if let duration = workoutDuration {
            data.workoutDuration = WorkoutDuration(rawValue: duration)
        }

        if let equipment = availableEquipment {
            data.availableEquipment = Equipment(rawValue: equipment)
        }

        data.injuries = injuries.compactMap { injuryDict in
            guard let type = injuryDict["type"] else { return nil }

            switch type {
            case "none":
                return .none
            case "shoulders":
                return .shoulders
            case "lower_back":
                return .lowerBack
            case "knees":
                return .knees
            case "wrists":
                return .wrists
            case "custom":
                if let value = injuryDict["value"] {
                    return .custom(value)
                }
                return nil
            default:
                return nil
            }
        }

        data.completedAt = completedAt

        return data
    }
}
