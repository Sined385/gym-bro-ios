//
//  ImageRenderer+ShareCard.swift
//  GymBro
//
//  Rasterizes a ShareCardView to a 1080×1920 PNG for external share targets
//  (Instagram Stories, WhatsApp, Photos save).
//

import SwiftUI
import UIKit

@MainActor
enum ShareCardRasterizer {
    /// Renders the card at 9:16 Instagram Stories resolution. `scale = 3`
    /// matches Retina device sharpness even though the renderer targets a
    /// fixed pixel size — the result is a clean 1080×1920 PNG either way.
    static func render(config: ShareConfig, workout: WorkoutSnapshot) -> UIImage? {
        let card = ShareCardView(config: config, workout: workout)
            .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}
