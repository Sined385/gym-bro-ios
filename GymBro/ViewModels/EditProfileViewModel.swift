//
//  EditProfileViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation
import Combine

@MainActor
final class EditProfileViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var displayName: String = ""
    @Published var username: String = ""
    @Published var avatarUrl: String?
    @Published var avatarImageData: Data?
    @Published var isCheckingUsername: Bool = false
    @Published var usernameAvailable: Bool? = nil
    @Published var usernameError: String? = nil
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var didSave: Bool = false

    // MARK: - Private

    private let networkService: NetworkServiceProtocol
    private var originalUsername: String = ""
    private var usernameCheckTask: Task<Void, Never>?

    // MARK: - Init

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    // MARK: - Prefill

    func prefill(name: String, username: String, avatarUrl: String?) {
        if displayName.isEmpty { displayName = name }
        if self.username.isEmpty {
            self.username = username
            originalUsername = username
        }
        if self.avatarUrl == nil { self.avatarUrl = avatarUrl }
        if !username.isEmpty { usernameAvailable = true }
    }

    // MARK: - Load

    func loadProfile() async {
        let hasPrefill = !displayName.isEmpty || !username.isEmpty
        if !hasPrefill {
            isLoading = true
        }
        do {
            let profile = try await networkService.request(
                UserRouter.getProfile.endpoint,
                responseType: UserProfileResponse.self
            )
            displayName = profile.fullName ?? ""
            username = profile.username ?? ""
            originalUsername = profile.username ?? ""
            avatarUrl = profile.avatarUrl
            usernameAvailable = true // current username is valid
        } catch {
            if !hasPrefill {
                errorMessage = "Could not load profile"
            }
        }
        isLoading = false
    }

    // MARK: - Update Methods

    func updateDisplayName(_ name: String) {
        displayName = name
    }

    func updateUsername(_ newUsername: String) {
        let sanitized = newUsername.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        username = sanitized
        usernameError = nil
        usernameAvailable = nil

        if sanitized == originalUsername {
            usernameAvailable = true
            return
        }

        if sanitized.count < 3 {
            usernameError = sanitized.isEmpty ? nil : "Username must be at least 3 characters"
            return
        }
        if sanitized.count > 30 {
            usernameError = "Username must be at most 30 characters"
            return
        }

        debounceCheckUsername()
    }

    func setAvatarImage(_ data: Data) {
        avatarImageData = data
    }

    func removeAvatar() {
        avatarImageData = nil
        avatarUrl = nil
    }

    // MARK: - Save

    var canSave: Bool {
        let hasName = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidUsername = username.count >= 3 && username.count <= 30 && usernameError == nil
        let isAvailable = usernameAvailable == true
        return hasName && hasValidUsername && isAvailable && !isSaving
    }

    func save() async {
        guard canSave else { return }

        isSaving = true
        errorMessage = nil

        do {
            // Upload avatar if new image selected
            if let imageData = avatarImageData {
                let multipart = [
                    MultipartFormData(
                        data: imageData,
                        name: "file",
                        fileName: "avatar.jpg",
                        mimeType: "image/jpeg"
                    )
                ]
                let response = try await networkService.uploadMultipart(
                    UserRouter.uploadAvatar(imageData: imageData).endpoint,
                    multipartData: multipart,
                    responseType: AvatarUploadResponse.self
                )
                avatarUrl = response.avatarUrl
            }

            // Update profile
            var body: [String: Any] = [
                "full_name": displayName,
                "username": username,
            ]
            if let url = avatarUrl {
                body["avatar_url"] = url
            }

            try await networkService.request(UserRouter.updateProfile(body: body).endpoint)
            didSave = true
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }

        isSaving = false
    }

    // MARK: - Private

    private func debounceCheckUsername() {
        usernameCheckTask?.cancel()
        let currentUsername = username
        guard currentUsername.count >= 3 else { return }

        isCheckingUsername = true
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await checkUsernameAvailability(currentUsername)
        }
    }

    private func checkUsernameAvailability(_ username: String) async {
        do {
            let response = try await networkService.request(
                UserRouter.checkUsername(username: username).endpoint,
                responseType: UsernameCheckResponse.self
            )
            guard self.username == username else { return }
            usernameAvailable = response.available
            if !response.available {
                usernameError = "Username is already taken"
            } else {
                usernameError = nil
            }
        } catch {
            usernameAvailable = nil
            usernameError = nil
        }
        isCheckingUsername = false
    }
}

// MARK: - Response Models

struct UserProfileResponse: Decodable {
    let id: String
    let email: String
    let fullName: String?
    let username: String?
    let avatarUrl: String?
}

struct UsernameCheckResponse: Decodable {
    let available: Bool
}

struct AvatarUploadResponse: Decodable {
    let avatarUrl: String
}
