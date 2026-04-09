//
//  ExercisePreviewViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-31.
//

import SwiftUI
import Combine

@MainActor
final class ExercisePreviewViewModel: ObservableObject {

    // MARK: - Published

    @Published var previousSessions: [PreviousSessionEntry] = []
    @Published var isLoading = false

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol

    // MARK: - Init

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    // MARK: - Public

    func loadData(for libraryExerciseId: String) async {
        isLoading = true
        defer { isLoading = false }

        previousSessions = await loadPreviousSets(for: libraryExerciseId)
    }

    // MARK: - Private

    private func loadPreviousSets(for libraryExerciseId: String) async -> [PreviousSessionEntry] {
        do {
            let response = try await networkService.request(
                ExerciseRouter.previousSets(exerciseId: libraryExerciseId).endpoint,
                responseType: PreviousSetsResponse.self
            )
            return response.sessions
        } catch {
            return []
        }
    }
}
