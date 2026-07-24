//
//  ExerciseNameLocalizer.swift
//  GymBro
//
//  Ukrainian display names for system exercises. Canonical English
//  names stay everywhere in the data layer (they're identity for the
//  API's matching/dedup logic); this maps external_id → localized name
//  at DISPLAY time only. One cached fetch localizes every surface —
//  library, sessions, plans, history, community cards — because all of
//  those payloads carry externalId.
//

import Foundation
import Combine

@MainActor
final class ExerciseNameLocalizer: ObservableObject {

    static let shared = ExerciseNameLocalizer()

    /// external_id → localized name. Empty when the app language is
    /// English (lookup becomes a no-op passthrough).
    @Published private(set) var map: [String: String] = [:]

    private var loadTask: Task<Void, Never>?

    private static var appLanguage: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return dir.appendingPathComponent("exercise-names-\(appLanguage).json")
    }

    private init() {
        // Serve last-known translations immediately; refresh in background.
        if Self.appLanguage != "en",
           let data = try? Data(contentsOf: Self.cacheURL),
           let cached = try? JSONDecoder().decode([String: String].self, from: data) {
            map = cached
        }
    }

    /// Display name for an exercise. Falls back to the stored (English
    /// or user-typed) name — automatically correct for custom exercises,
    /// which have no externalId.
    func localized(name: String, externalId: String?) -> String {
        guard let externalId, let translated = map[externalId] else { return name }
        return translated
    }

    /// Fetch/refresh the map. No-op for English. Call on app start.
    func refresh() {
        guard Self.appLanguage != "en", loadTask == nil else { return }
        loadTask = Task { [weak self] in
            defer { self?.loadTask = nil }
            do {
                let network = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
                let response = try await network.request(
                    ExerciseRouter.translations(lang: Self.appLanguage).endpoint,
                    responseType: TranslationsResponse.self
                )
                self?.map = response.translations
                if let data = try? JSONEncoder().encode(response.translations) {
                    try? data.write(to: Self.cacheURL, options: .atomic)
                }
            } catch {
                // Cached (or English) names keep working.
                print("[ExerciseNameLocalizer] refresh failed: \(error)")
            }
        }
    }

    private struct TranslationsResponse: Decodable {
        let translations: [String: String]
    }
}

/// Convenience for views — display-time exercise-name localization.
@MainActor
func localizedExerciseName(_ name: String, externalId: String?) -> String {
    ExerciseNameLocalizer.shared.localized(name: name, externalId: externalId)
}
