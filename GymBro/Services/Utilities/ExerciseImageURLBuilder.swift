//
//  ExerciseImageURLBuilder.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-06.
//

import Foundation

enum ExerciseImageURLBuilder {
    private static let baseURL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises"

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
