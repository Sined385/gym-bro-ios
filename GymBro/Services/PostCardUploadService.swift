//
//  PostCardUploadService.swift
//  GymBro
//
//  Rasterizes the share card via ShareCardRasterizer and uploads it to the
//  Supabase Storage `post-cards` bucket. The returned URL becomes the post's
//  `card_image_url`, used by `/p/:postId` for og:image link previews.
//

import Foundation
import UIKit
import Supabase

@MainActor
enum PostCardUploadService {
    /// Renders the card from `config`+`workout`, encodes JPEG (0.85), and
    /// uploads to `post-cards/{userId}/{UUID}.jpg`. Returns the public URL.
    /// Throws on any failure; callers should fall back to posting without a
    /// card_image_url (in-app feed still works via share_config).
    static func uploadCardImage(
        config: ShareConfig,
        workout: WorkoutSnapshot
    ) async throws -> String {
        guard let image = ShareCardRasterizer.render(config: config, workout: workout) else {
            throw NSError(
                domain: "PostCardUploadService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Card rasterization failed"]
            )
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(
                domain: "PostCardUploadService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "JPEG encoding failed"]
            )
        }
        return try await uploadJPEG(jpeg, prefix: "card")
    }

    /// Uploads arbitrary image bytes (e.g. a user-picked background photo)
    /// to the same `post-cards` bucket. Re-encodes via UIImage so the file
    /// is a properly-sized JPEG regardless of the source format/orientation.
    static func uploadRawImageData(_ data: Data) async throws -> String {
        guard let image = UIImage(data: data) else {
            throw NSError(
                domain: "PostCardUploadService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't decode the picked image"]
            )
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(
                domain: "PostCardUploadService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "JPEG encoding failed"]
            )
        }
        return try await uploadJPEG(jpeg, prefix: "bg")
    }

    private static func uploadJPEG(_ jpeg: Data, prefix: String) async throws -> String {
        let session = try await SupabaseConfig.client.auth.session
        let userId = session.user.id.uuidString.lowercased()
        let fileName = "\(userId)/\(prefix)-\(UUID().uuidString.lowercased()).jpg"

        _ = try await SupabaseConfig.client.storage
            .from("post-cards")
            .upload(fileName, data: jpeg, options: .init(contentType: "image/jpeg"))

        let publicUrl = try SupabaseConfig.client.storage
            .from("post-cards")
            .getPublicURL(path: fileName)

        return publicUrl.absoluteString
    }
}
