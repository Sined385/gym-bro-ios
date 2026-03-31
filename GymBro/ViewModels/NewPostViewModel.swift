//
//  NewPostViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
final class NewPostViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var content: String = ""
    @Published var photoData: Data?
    @Published var photoPreview: Image?
    @Published var uploadedPhotoUrl: String?
    @Published var isUploadingPhoto: Bool = false
    @Published var isPosting: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    // MARK: - Computed

    var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isPosting && !isUploadingPhoto
    }

    // MARK: - Actions

    func createPost() async -> CommunityPost? {
        guard canPost else { return nil }
        isPosting = true
        errorMessage = nil

        // If there's photo data but not yet uploaded, upload first
        if photoData != nil && uploadedPhotoUrl == nil {
            await uploadPhoto()
        }

        do {
            let post = try await networkService.request(
                CommunityRouter.createPost(
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    visibility: "global",
                    workoutSessionId: nil,
                    photoUrl: uploadedPhotoUrl
                ).endpoint,
                responseType: CommunityPost.self
            )
            isPosting = false
            return post
        } catch {
            errorMessage = "Failed to create post. Please try again."
            isPosting = false
            return nil
        }
    }

    func handleImageData(_ data: Data) async {
        photoData = data
        if let uiImage = UIImage(data: data) {
            photoPreview = Image(uiImage: uiImage)
        }
        await uploadPhoto()
    }

    func uploadPhoto() async {
        guard let data = photoData else { return }
        guard let jpegData = UIImage(data: data)?.jpegData(compressionQuality: 0.7) else { return }

        isUploadingPhoto = true

        do {
            let session = try await SupabaseConfig.client.auth.session
            let userId = session.user.id.uuidString.lowercased()
            let fileName = "\(userId)/\(UUID().uuidString.lowercased()).jpg"

            _ = try await SupabaseConfig.client.storage
                .from("post-photos")
                .upload(fileName, data: jpegData, options: .init(contentType: "image/jpeg"))

            let publicUrl = try SupabaseConfig.client.storage
                .from("post-photos")
                .getPublicURL(path: fileName)

            uploadedPhotoUrl = publicUrl.absoluteString
        } catch {
            errorMessage = "Photo upload failed: \(error.localizedDescription)"
        }

        isUploadingPhoto = false
    }

    func removePhoto() {
        photoData = nil
        photoPreview = nil
        uploadedPhotoUrl = nil
    }

    func reset() {
        content = ""
        photoData = nil
        photoPreview = nil
        uploadedPhotoUrl = nil
        isUploadingPhoto = false
        errorMessage = nil
    }
}
