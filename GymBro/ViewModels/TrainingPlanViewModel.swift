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
            // Mock fallback for development
            plan = Self.mockPlan
            days = Self.mockDays
            todayIndex = 0 // First day in partial week
            errorMessage = nil
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
            sessionManager.startSession(response)
        } catch {
            // Mock fallback
            let mockResponse = SessionResponse(
                id: UUID().uuidString,
                title: days.first(where: { $0.id == dayId })?.sessionTitle ?? "Training Session",
                type: "strength",
                status: "active",
                startedAt: ISO8601DateFormatter().string(from: Date()),
                completedAt: nil,
                durationMinutes: nil,
                calories: nil,
                aiGenerated: true,
                aiMessage: nil,
                exercises: mockExercisesForDay(dayId)
            )
            sessionManager.startSession(mockResponse)
            errorMessage = nil
        }

        isStartingSession = false
    }

    private func mockExercisesForDay(_ dayId: String) -> [DashboardExercise] {
        guard let day = days.first(where: { $0.id == dayId }),
              let exercises = day.exercises else { return [] }
        return exercises.enumerated().map { index, ex in
            DashboardExercise(
                id: UUID().uuidString,
                name: ex.name,
                stepNumber: index + 1,
                setsDisplay: ex.setsDisplay,
                accentColor: ex.accentColor ?? "#E86A75",
                libraryExerciseId: ex.libraryExerciseId,
                muscleGroup: ex.muscleGroup,
                equipment: nil,
                suggestedWeight: ex.suggestedWeight
            )
        }
    }

    // MARK: - Mock Data

    private static var mockPlan: TrainingPlanData {
        TrainingPlanData(
            id: "mock-plan",
            weekNumber: 4,
            primaryGoals: ["build_muscle"],
            experienceLevel: "intermediate"
        )
    }

    private static var mockDays: [PlanDayData] {
        // Partial week mock: Wed-Sun (as if plan was generated on Wednesday)
        [
            PlanDayData(
                id: "day-2",
                dayOfWeek: 2,
                dayLabel: "Wed",
                dayType: "training",
                status: "pending",
                sessionTitle: "Push Day",
                sessionType: "strength",
                muscleGroups: ["Chest", "Shoulders", "Triceps"],
                exercises: [
                    PlanExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", setsDisplay: "4 \u{00D7} 10", libraryExerciseId: nil, accentColor: "#E86A75"),
                    PlanExercise(name: "Lateral Raises", muscleGroup: "Shoulders", setsDisplay: "3 \u{00D7} 12", libraryExerciseId: nil, accentColor: "#30C08D"),
                    PlanExercise(name: "Cable Flyes", muscleGroup: "Chest", setsDisplay: "3 \u{00D7} 12", libraryExerciseId: nil, accentColor: "#7A82F6"),
                    PlanExercise(name: "Tricep Pushdowns", muscleGroup: "Triceps", setsDisplay: "3 \u{00D7} 12", libraryExerciseId: nil, accentColor: "#F5A623"),
                    PlanExercise(name: "Dips", muscleGroup: "Chest", setsDisplay: "3 \u{00D7} 10", libraryExerciseId: nil, accentColor: "#E86A75"),
                ],
                workoutSession: nil,
                aiNotes: nil
            ),
            PlanDayData(
                id: "day-3",
                dayOfWeek: 3,
                dayLabel: "Thu",
                dayType: "rest",
                status: "pending",
                sessionTitle: nil,
                sessionType: nil,
                muscleGroups: nil,
                exercises: nil,
                workoutSession: nil,
                aiNotes: nil
            ),
            PlanDayData(
                id: "day-4",
                dayOfWeek: 4,
                dayLabel: "Fri",
                dayType: "training",
                status: "pending",
                sessionTitle: "Pull Day",
                sessionType: "strength",
                muscleGroups: ["Back", "Biceps", "Core"],
                exercises: [
                    PlanExercise(name: "Deadlift", muscleGroup: "Back", setsDisplay: "4 \u{00D7} 6", libraryExerciseId: nil, accentColor: "#E86A75"),
                    PlanExercise(name: "Lat Pulldown", muscleGroup: "Back", setsDisplay: "3 \u{00D7} 10", libraryExerciseId: nil, accentColor: "#30C08D"),
                    PlanExercise(name: "Barbell Curl", muscleGroup: "Biceps", setsDisplay: "3 \u{00D7} 10", libraryExerciseId: nil, accentColor: "#7A82F6"),
                    PlanExercise(name: "Face Pulls", muscleGroup: "Shoulders", setsDisplay: "3 \u{00D7} 15", libraryExerciseId: nil, accentColor: "#F5A623"),
                ],
                workoutSession: nil,
                aiNotes: nil
            ),
            PlanDayData(
                id: "day-5",
                dayOfWeek: 5,
                dayLabel: "Sat",
                dayType: "training",
                status: "pending",
                sessionTitle: "Full Body",
                sessionType: "strength",
                muscleGroups: ["Chest", "Back", "Legs"],
                exercises: [
                    PlanExercise(name: "Bench Press", muscleGroup: "Chest", setsDisplay: "3 \u{00D7} 10", libraryExerciseId: nil, accentColor: "#E86A75"),
                    PlanExercise(name: "Barbell Row", muscleGroup: "Back", setsDisplay: "3 \u{00D7} 10", libraryExerciseId: nil, accentColor: "#30C08D"),
                    PlanExercise(name: "Leg Press", muscleGroup: "Legs", setsDisplay: "3 \u{00D7} 12", libraryExerciseId: nil, accentColor: "#7A82F6"),
                    PlanExercise(name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders", setsDisplay: "3 \u{00D7} 10", libraryExerciseId: nil, accentColor: "#F5A623"),
                ],
                workoutSession: nil,
                aiNotes: nil
            ),
            PlanDayData(
                id: "day-6",
                dayOfWeek: 6,
                dayLabel: "Sun",
                dayType: "rest",
                status: "pending",
                sessionTitle: nil,
                sessionType: nil,
                muscleGroups: nil,
                exercises: nil,
                workoutSession: nil,
                aiNotes: nil
            ),
        ]
    }
}
