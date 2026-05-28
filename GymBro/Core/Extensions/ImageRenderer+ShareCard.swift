//
//  ImageRenderer+ShareCard.swift
//  GymBro
//
//  Rasterizes a ShareCardView to a 1080×1920 PNG for external share targets
//  (Instagram Stories, WhatsApp, Photos save, post-card uploads to Storage).
//

import SwiftUI
import UIKit

@MainActor
enum ShareCardRasterizer {
    /// Renders the card at 9:16 Instagram Stories resolution. If the config
    /// has a photo background, we fetch it synchronously first — ImageRenderer
    /// can't wait on CachedAsyncImage, so without the pre-fetch the rasterized
    /// output drops back to the placeholder color instead of the user's photo.
    static func render(config: ShareConfig, workout: WorkoutSnapshot) async -> UIImage? {
        let bgImage: UIImage? = await loadBackgroundImage(for: config)
        let card = ShareCardView(
            config: config,
            workout: workout,
            prerenderedBackground: bgImage
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        return renderer.uiImage
    }

    private static func loadBackgroundImage(for config: ShareConfig) async -> UIImage? {
        guard let url = config.background.photoURL else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
