//
//  FavoritesService.swift
//  GymBro
//
//  Shared, app-wide source of truth for the user's favorited exercises.
//  Library list, session cards, and the exercise logging screen all observe
//  this so a heart-tap in one place flips the icon everywhere instantly.
//

import Foundation
import Combine

@MainActor
final class FavoritesService: ObservableObject {

    @Published private(set) var favoriteIds: Set<String> = []

    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func isFavorite(_ exerciseId: String) -> Bool {
        favoriteIds.contains(exerciseId)
    }

    /// Replace the local set from a freshly-loaded exercise list. The backend
    /// returns `is_favorite` on every exercise; this lets the library load
    /// double as a favorites sync without a separate request.
    func seedFromLibrary(_ items: [ExerciseLibraryItem]) {
        favoriteIds = Set(items.filter(\.isFavorite).map(\.id))
    }

    /// Flip the favorite state for an exercise. Optimistic — the local set
    /// updates immediately and reverts on API failure so the UI never lies
    /// about the persisted state for long.
    func toggle(exerciseId: String) async {
        let wasFavorite = favoriteIds.contains(exerciseId)
        if wasFavorite {
            favoriteIds.remove(exerciseId)
        } else {
            favoriteIds.insert(exerciseId)
        }

        do {
            if wasFavorite {
                _ = try await networkService.request(
                    ExerciseRouter.unfavorite(exerciseId: exerciseId).endpoint,
                    responseType: FavoriteToggleResponse.self
                )
            } else {
                _ = try await networkService.request(
                    ExerciseRouter.favorite(exerciseId: exerciseId).endpoint,
                    responseType: FavoriteToggleResponse.self
                )
            }
        } catch {
            // Revert on failure.
            if wasFavorite {
                favoriteIds.insert(exerciseId)
            } else {
                favoriteIds.remove(exerciseId)
            }
        }
    }
}

private struct FavoriteToggleResponse: Decodable {
    let exerciseId: String
    let isFavorite: Bool
}
