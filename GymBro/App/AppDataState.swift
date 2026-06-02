//
//  AppDataState.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-31.
//

import Foundation
import Combine

/// Single shared snapshot of server-driven state that Home, Plan, and
/// Coach tabs read from. Owns the canonical `/home/dashboard` fetch —
/// individual ViewModels stopped maintaining their own copies in
/// Phase 3 of the orchestrator refactor (commit history: backend
/// commits a47754e / c66188b / 6db837d / 30ecc9c).
///
/// Refresh triggers:
///   - app launch (HomeView .task)
///   - pull-to-refresh on any tab
///   - workout completion (existing `triggerReload` path)
///   - Coach SSE `session_created` / `plan_modified` / `plan_generated`
///   - scenePhase `.active` after >5 min background (cheap freshness)
@MainActor
final class AppDataState: ObservableObject {
    /// Bumped on every refresh; legacy observers (HomeVM, TrainingPlanVM)
    /// still watch this to know when state changed. Phase 3 keeps this
    /// signal so the migration to AppContext-driven reads can happen
    /// incrementally without breaking existing reactivity.
    @Published private(set) var reloadVersion: Int = 0

    /// Latest dashboard payload. Single source of truth for week
    /// stats, motivation, planned workout, today's completed session,
    /// daily challenge, etc.
    @Published private(set) var dashboard: DashboardResponse?

    /// Active plan metadata (id, weekNumber, primaryGoals,
    /// experienceLevel). Nil when the user hasn't generated a plan
    /// yet or when the backend response lacks `planDays` (pre-Phase-3
    /// servers).
    @Published private(set) var plan: TrainingPlanData?

    /// Full 7-day plan layout. TrainingPlanView reads from here
    /// instead of issuing its own GET /api/v1/plans.
    @Published private(set) var planDays: [PlanDayData] = []

    /// yyyy-MM-dd strings for completed-workout calendar dots
    /// across the current + previous month. Two months covers the
    /// vast majority of calendar interactions without an extra
    /// /completed-days call.
    @Published private(set) var completedDates: Set<String> = []

    /// Per-exercise best set + suggested progression for the last
    /// 14 days. Surfaces "you bench-pressed 85×5 on Jun 1" style
    /// hints without a separate fetch.
    @Published private(set) var recentLiftsSummary: [RecentLiftSummary] = []

    /// Timestamp of the last successful refresh — used by tabs to
    /// decide whether scenePhase `.active` should trigger a refresh.
    @Published private(set) var lastRefreshAt: Date?

    /// Set when a workout has been fully completed on the server. MainTabView
    /// observes this and presents the (optional) post-workout share screen
    /// after the active session has already been torn down — so even if the
    /// user kills the app from the share sheet, there's no half-state to
    /// restore on next launch.
    @Published var pendingShareData: CompletedWorkoutShareData?

    /// Set when ShareEditorView successfully posts to the community. MainTabView
    /// switches to the Community tab; CommunityFeedView injects the post at
    /// the top of its list and clears the slot. This avoids the user landing
    /// back on their previous tab unsure whether the share actually went out.
    @Published var pendingFeedPost: CommunityPost?

    private let networkService: NetworkServiceProtocol
    private var refreshTask: Task<Void, Never>?

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    /// Re-emit a reload signal without hitting the network. Existing
    /// callers used this pre-Phase-3 to invalidate VM caches; the
    /// AppContext-aware path is `refresh()` below. Kept for
    /// compatibility with tear-down code that doesn't want to trigger
    /// a network call.
    func triggerReload() {
        reloadVersion += 1
    }

    /// Fetch /home/dashboard once and atomically write all snapshot
    /// properties. Coalesces overlapping calls — a second invocation
    /// while the first is in-flight is a no-op (awaits the same task).
    func refresh(reason: RefreshReason = .manual) async {
        if let existing = refreshTask {
            await existing.value
            return
        }
        let task = Task<Void, Never> { [weak self] in
            await self?.performRefresh(reason: reason)
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    enum RefreshReason {
        case appLaunch
        case pullToRefresh
        case sessionCompleted
        case coachAction
        case scenePhaseActive
        case manual
    }

    private func performRefresh(reason: RefreshReason) async {
        do {
            let response = try await networkService.request(
                HomeRouter.dashboard.endpoint,
                responseType: DashboardResponse.self,
            )
            self.dashboard = response
            // plan_days is only populated on Phase-3-or-later
            // backends. Treat absence as "no plan changes" — keep
            // whatever's already in the snapshot.
            if let days = response.planDays {
                self.planDays = days
                // The dashboard doesn't ship `plan` metadata
                // (week number, etc.) directly. If we have non-empty
                // plan_days, ask /plans for the metadata on first
                // hydration; otherwise reuse the existing value.
                if self.plan == nil {
                    await loadPlanMetadata()
                }
            }
            if let current = response.completedDatesCurrentMonth {
                self.completedDates.formUnion(current)
            }
            if let prev = response.completedDatesPreviousMonth {
                self.completedDates.formUnion(prev)
            }
            if let lifts = response.recentLiftsSummary {
                self.recentLiftsSummary = lifts
            }
            self.lastRefreshAt = Date()
            self.reloadVersion += 1
            _ = reason
        } catch {
            // Silently fall back — VMs that still own their own fetch
            // path will take over. Phase 3 keeps the legacy fetches
            // as a safety net until everything's verified.
        }
    }

    /// Pulls `plan` metadata (id, weekNumber, goals, level) from
    /// /api/v1/plans when we have `planDays` but no `plan` yet. The
    /// dashboard payload ships `plan_days` but not the parent plan
    /// record — keeping a fetch here is the smallest delta vs.
    /// extending the dashboard response further.
    private func loadPlanMetadata() async {
        do {
            let response = try await networkService.request(
                PlanRouter.getActivePlan.endpoint,
                responseType: TrainingPlanResponse.self,
            )
            self.plan = response.plan
        } catch {
            // Optional fetch — if it fails, plan metadata stays nil
            // and the TrainingPlanView falls back to its own load.
        }
    }
}

/// Self-contained snapshot of a just-completed workout, used to drive the
/// share screen without holding on to the SessionFlowViewModel after teardown.
struct CompletedWorkoutShareData: Identifiable {
    let id = UUID()
    let sessionId: String
    let sessionTitle: String
    let exercises: [ActiveSessionExercise]
    let effortLevel: Int
    let energyLevel: Int
    let durationMinutes: Int?
    /// Calories burned (from session response or Apple Watch summary).
    var calories: Int? = nil
    /// Average heart rate during the workout (only set when Apple Watch was
    /// the HR source — past workouts loaded from history don't carry this).
    var avgHeartRate: Int? = nil
}
