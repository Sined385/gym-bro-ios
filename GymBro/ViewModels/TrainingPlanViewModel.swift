//
//  TrainingPlanViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class TrainingPlanViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var plan: TrainingPlanData?
    @Published var days: [PlanDayData] = []
    @Published var todayIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published var isStartingSession: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let sessionManager: ActiveSessionManager
    private let appDataState: AppDataState
    private var hasLoaded = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, sessionManager: ActiveSessionManager, appDataState: AppDataState) {
        self.networkService = networkService
        self.sessionManager = sessionManager
        self.appDataState = appDataState

        appDataState.$reloadVersion
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadPlan()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load If Needed

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadPlan()
    }

    // MARK: - Computed Properties

    var goalDisplayText: String {
        guard let plan = plan else { return "Training Plan" }
        let goal = plan.primaryGoals.first?
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ") ?? "Training"
        let level = plan.experienceLevel.prefix(1).uppercased() + plan.experienceLevel.dropFirst()
        return "\(goal) \u{2022} \(level)"
    }

    var weekLabel: String {
        guard let plan = plan else { return "WEEK 1" }
        return "WEEK \(plan.weekNumber)"
    }

    // MARK: - Data Loading

    func loadPlan() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await networkService.request(
                PlanRouter.getActivePlan.endpoint,
                responseType: TrainingPlanResponse.self
            )
            plan = response.plan
            days = response.days
            todayIndex = response.todayIndex
        } catch {
            print("[TrainingPlanVM] loadPlan failed: \(error)")
            errorMessage = "Failed to load plan"
        }

        isLoading = false
    }

    func startPlanSession(dayId: String) async {
        isStartingSession = true
        errorMessage = nil

        do {
            let response = try await networkService.request(
                PlanRouter.startPlanSession(dayId: dayId).endpoint,
                responseType: SessionResponse.self
            )
            sessionManager.openSession(response)
        } catch {
            print("[TrainingPlanVM] startPlanSession failed: \(error)")
            errorMessage = "Failed to start session"
        }

        isStartingSession = false
    }

}
