//
//  SharedTemplatePreviewViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-02.
//

import Foundation
import Combine

@MainActor
final class SharedTemplatePreviewViewModel: ObservableObject {
    @Published var template: SharedTemplateResponse?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var savedSuccessfully = false
    @Published var errorMessage: String?

    let shareCode: String
    private let networkService: NetworkServiceProtocol
    private let sessionManager: ActiveSessionManager

    init(shareCode: String, networkService: NetworkServiceProtocol, sessionManager: ActiveSessionManager) {
        self.shareCode = shareCode
        self.networkService = networkService
        self.sessionManager = sessionManager
    }

    func loadTemplate() async {
        isLoading = true
        defer { isLoading = false }
        do {
            template = try await networkService.request(
                SharedRouter.getShared(code: shareCode).endpoint,
                responseType: SharedTemplateResponse.self
            )
        } catch {
            errorMessage = "Could not load this workout"
        }
    }

    func saveToLibrary() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await networkService.request(
                TemplateRouter.saveShared(code: shareCode).endpoint,
                responseType: WorkoutTemplate.self
            )
            savedSuccessfully = true
        } catch {
            errorMessage = "Could not save to library"
        }
    }

    func startWorkout() async {
        sessionManager.requestSessionStart { [weak self] in
            guard let self else { return }
            self.isSaving = true
            do {
                let saved = try await self.networkService.request(
                    TemplateRouter.saveShared(code: self.shareCode).endpoint,
                    responseType: WorkoutTemplate.self
                )
                let session = try await self.networkService.request(
                    TemplateRouter.start(templateId: saved.id).endpoint,
                    responseType: SessionResponse.self
                )
                self.sessionManager.openSession(session)
            } catch {
                self.errorMessage = "Could not start workout"
            }
            self.isSaving = false
        }
    }

    func followCreator() async {
        guard let creatorId = template?.creator?.id else { return }
        do {
            try await networkService.request(
                CommunityRouter.followUser(userId: creatorId).endpoint
            )
        } catch {
            // Silently fail — non-critical action
        }
    }
}
