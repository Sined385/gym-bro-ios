//
//  ExerciseImageURLBuilder.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-06.
//

import Foundation

enum ExerciseImageURLBuilder {
    /// Public URL prefix for exercise images served from our Supabase
    /// Storage bucket `exercise-images`. Layout matches `<external_id>/{0,1}.jpg`
    /// — identical to the upstream free-exercise-db repo we used to
    /// hot-link, so the only thing that changes here is the host.
    /// Derived from `AppEnvironment.current.supabaseURL` so staging /
    /// prod / dev each point at the matching project automatically.
    private static var baseURL: String {
        let supabaseURL = AppEnvironment.current.supabaseURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(supabaseURL)/storage/v1/object/public/exercise-images"
    }

    /// Returns [0.jpg, 1.jpg] URLs for gallery/carousel display
    static func imageURLs(for externalId: String?) -> [URL] {
        guard let externalId, !externalId.isEmpty else { return [] }
        return [
            URL(string: "\(baseURL)/\(externalId)/0.jpg"),
            URL(string: "\(baseURL)/\(externalId)/1.jpg")
        ].compactMap { $0 }
    }

    /// Returns just the 0.jpg URL for thumbnail display
    static func thumbnailURL(for externalId: String?) -> URL? {
        guard let externalId, !externalId.isEmpty else { return nil }
        return URL(string: "\(baseURL)/\(externalId)/0.jpg")
    }
}
