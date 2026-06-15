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
    let subscriptionManager: SubscriptionManager
    private var hasLoaded = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, sessionManager: ActiveSessionManager, appDataState: AppDataState, subscriptionManager: SubscriptionManager) {
        self.networkService = networkService
        self.sessionManager = sessionManager
        self.appDataState = appDataState
        self.subscriptionManager = subscriptionManager

        // Phase 3: read plan + days from the shared AppContext snapshot
        // when it has them. The backend now ships `plan_days` inside
        // /home/dashboard, so when AppContext refreshes, we get the
        // plan for free without a separate /api/v1/plans round trip.
        appDataState.$planDays
            .receive(on: DispatchQueue.main)
            .sink { [weak self] days in
                guard let self else { return }
                if !days.isEmpty {
                    self.days = days
                    self.todayIndex = Self.computeTodayIndex(in: days)
                }
            }
            .store(in: &cancellables)

        appDataState.$plan
            .receive(on: DispatchQueue.main)
            .sink { [weak self] plan in
                guard let self else { return }
                if let plan {
                    self.plan = plan
                }
            }
            .store(in: &cancellables)

        // Legacy reloadVersion path — keep as a safety net while the
        // AppContext hydration settles. If AppContext.refresh hasn't
        // populated `planDays` yet (older backend, first launch),
        // fall back to the direct /plans fetch.
        appDataState.$reloadVersion
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    guard let self else { return }
                    if self.appDataState.planDays.isEmpty {
                        await self.loadPlan()
                    }
                }
            }
            .store(in: &cancellables)

        // When premium status changes, forward to view and reload plan
        subscriptionManager.$isPremium
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] isPremium in
                self?.objectWillChange.send()
                if isPremium {
                    Task { [weak self] in
                        await self?.loadPlan()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load If Needed

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        // Prefer the shared AppContext snapshot; only hit /plans
        // directly when the snapshot doesn't have plan_days yet
        // (e.g., first launch before AppContext.refresh completes).
        if appDataState.planDays.isEmpty {
            await loadPlan()
        } else {
            self.days = appDataState.planDays
            self.todayIndex = Self.computeTodayIndex(in: appDataState.planDays)
            if let plan = appDataState.plan {
                self.plan = plan
            }
        }
    }

    /// Day-of-week index for today within the plan's days array.
    /// Mirrors what /api/v1/plans returns as `todayIndex` server-side,
    /// computed here client-side since the dashboard payload doesn't
    /// ship the field separately.
    private static func computeTodayIndex(in days: [PlanDayData]) -> Int {
        // toMondayDow: 0=Mon..6=Sun matches PlanDay.day_of_week.
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date()) // 1=Sun..7=Sat
        let todayDow = weekday == 1 ? 6 : weekday - 2
        return days.firstIndex(where: { $0.dayOfWeek == todayDow }) ?? 0
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
        sessionManager.requestSessionStart { [weak self] in
            guard let self else { return }
            self.isStartingSession = true
            self.errorMessage = nil

            do {
                let response = try await self.networkService.request(
                    PlanRouter.startPlanSession(dayId: dayId).endpoint,
                    responseType: SessionResponse.self
                )
                // Carry the plan_day_id forward — completion payload uses it
                // to link the new WorkoutSession row to the plan day. Without
                // this, the link only happens via the server-side reconcile
                // fallback, which mis-fired when the plan day already had
                // adapted_at set.
                self.sessionManager.openSession(response, planDayId: dayId)
            } catch {
                print("[TrainingPlanVM] startPlanSession failed: \(error)")
                self.errorMessage = "Failed to start session"
            }

            self.isStartingSession = false
        }
    }

}
