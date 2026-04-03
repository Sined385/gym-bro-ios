//
//  WorkoutTemplatesViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-02.
//

import Foundation
import Combine

struct ShareTemplateResponse: Decodable {
    let shareUrl: String
    let shareCode: String
}

@MainActor
final class WorkoutTemplatesViewModel: ObservableObject {
    @Published var templates: [WorkoutTemplate] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var shareURL: URL?
    @Published var isSharing = false

    private let networkService: NetworkServiceProtocol
    private let sessionManager: ActiveSessionManager
    private let analyticsService: AnalyticsTrackingServiceProtocol

    init(networkService: NetworkServiceProtocol, sessionManager: ActiveSessionManager, analyticsService: AnalyticsTrackingServiceProtocol) {
        self.networkService = networkService
        self.sessionManager = sessionManager
        self.analyticsService = analyticsService
    }

    func loadTemplates() async {
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await networkService.request(
                TemplateRouter.list.endpoint,
                responseType: [WorkoutTemplate].self
            )
        } catch {
            // Keep existing templates on error
        }
    }

    func saveTemplate(name: String, sessionId: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let template = try await networkService.request(
                TemplateRouter.create(name: name, sessionIds: [sessionId]).endpoint,
                responseType: WorkoutTemplate.self
            )
            templates.insert(template, at: 0)
            return true
        } catch {
            return false
        }
    }

    func startFromTemplate(_ template: WorkoutTemplate) async {
        do {
            let response = try await networkService.request(
                TemplateRouter.start(templateId: template.id).endpoint,
                responseType: SessionResponse.self
            )
            sessionManager.openSession(response)
        } catch {
            // Error starting template
        }
    }

    func deleteTemplate(_ templateId: String) async {
        do {
            try await networkService.request(
                TemplateRouter.delete(templateId: templateId).endpoint
            )
            templates.removeAll { $0.id == templateId }
        } catch {
            // Error deleting
        }
    }

    func shareTemplate(_ template: WorkoutTemplate) async {
        isSharing = true
        defer { isSharing = false }
        do {
            let response = try await networkService.request(
                TemplateRouter.share(templateId: template.id).endpoint,
                responseType: ShareTemplateResponse.self
            )
            shareURL = URL(string: response.shareUrl)
            analyticsService.track("exercise_shared_as_link", properties: ["template_id": template.id])
        } catch {
            // Error sharing
        }
    }

    func renameTemplate(_ templateId: String, name: String) async {
        do {
            let updated = try await networkService.request(
                TemplateRouter.rename(templateId: templateId, name: name).endpoint,
                responseType: WorkoutTemplate.self
            )
            if let index = templates.firstIndex(where: { $0.id == templateId }) {
                templates[index] = updated
            }
        } catch {
            // Error renaming
        }
    }
}
