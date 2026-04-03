//
//  HomeViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-14.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Response Models

struct PlannedWorkoutResponse: Decodable {
    let type: String  // "training" or "rest"
    let planDayId: String?
    let sessionTitle: String?
    let sessionType: String?
    let muscleGroups: [String]?
    let status: String?
    let exercises: [PlannedExercise]?
}

struct PlannedExercise: Decodable, Identifiable {
    let name: String
    let muscleGroup: String
    let setsDisplay: String
    let libraryExerciseId: String?
    let accentColor: String
    let suggestedWeight: Double?
    let imageUrl: String?
    var id: String { name + setsDisplay }
}

struct DashboardResponse: Decodable {
    let user: DashboardUser
    let motivation: DashboardMotivation?
    let weekCompletedDays: [Int]
    let quickWorkout: DashboardSession?
    let plannedWorkout: PlannedWorkoutResponse?
    let weekWorkoutsTotal: Int?
    let weekWorkoutsCompleted: Int?
    let weekVolumeKg: Double?
    let weekStreak: Int?
    let weekAvgDurationMinutes: Int?
    let weekTotalCalories: Int?
    let todayCompletedSession: SessionHistory?
}

struct DashboardUser: Decodable {
    let name: String
    let avatarUrl: String?
}

struct DashboardMotivation: Decodable {
    let title: String
    let message: String
    let workoutsThisWeek: Int
    let personalRecords: [String]
}

struct DashboardSession: Decodable, Identifiable {
    let id: String
    let title: String
    let type: String
    let status: String?
    let durationMinutes: Int?
    let aiMessage: String?
    let exercises: [DashboardExercise]
}

struct SessionResponse: Decodable {
    let id: String
    let title: String
    let type: String
    let status: String
    let startedAt: String?
    let completedAt: String?
    let durationMinutes: Int?
    let calories: Int?
    let aiGenerated: Bool?
    let aiMessage: String?
    let exercises: [DashboardExercise]
}

struct DashboardExercise: Codable, Identifiable {
    let id: String
    let name: String
    let stepNumber: Int
    let setsDisplay: String
    let accentColor: String
    let libraryExerciseId: String?
    let muscleGroup: String?
    let equipment: String?
    let suggestedWeight: Double?
    let imageUrl: String?
}

// MARK: - History Response Models

struct SessionHistoryResponse: Decodable {
    let date: String
    let session: SessionHistory?
}

struct SessionHistory: Decodable, Identifiable {
    let id: String
    let sessionIds: [String]?
    let title: String
    let type: String
    let durationMinutes: Int?
    let calories: Int?
    let performanceScore: Int?
    let exercises: [HistoryExercise]
}

struct HistoryExercise: Decodable, Identifiable {
    let id: String
    let name: String
    let muscleGroup: String?
    let accentColor: String
    let stepNumber: Int
    var imageUrl: String? = nil
    let sets: [ExerciseSetData]
}

struct ExerciseSetData: Decodable, Identifiable {
    let setNumber: Int
    let weight: Double?
    let weightUnit: String
    let reps: Int
    var id: Int { setNumber }
}

struct CompletedDaysResponse: Decodable {
    let month: String
    let completedDates: [String]
}

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var userName: String = ""
    @Published var avatarUrl: String?
    @Published var motivation: DashboardMotivation?
    @Published var weekCompletedDays: Set<Int> = []
    @Published var quickWorkout: DashboardSession?
    @Published var activeSession: SessionResponse?
    @Published var isLoading: Bool = false
    @Published var isStartingSession: Bool = false
    @Published var errorMessage: String?
    @Published var selectedDate: Date?
    @Published var sessionHistory: SessionHistory?
    @Published var isLoadingHistory: Bool = false
    @Published var completedDates: Set<Date> = []
    @Published var todayCompletedSession: SessionHistory?
    @Published var plannedWorkout: PlannedWorkoutResponse?
    @Published var weekWorkoutsTotal: Int = 0
    @Published var weekWorkoutsCompleted: Int = 0
    @Published var weekVolumeKg: Double?
    @Published var weekStreak: Int?
    @Published var weekAvgDurationMinutes: Int?
    @Published var weekTotalCalories: Int?
    @Published var latestWeightKg: Double?
    @Published var restingHeartRate: Double?
    @Published var todayActiveEnergy: Double?
    @Published var latestBodyFat: Double?
    @Published var latestLeanBodyMass: Double?
    @Published var todayStepCount: Double?
    @Published var lastNightSleep: Double?
    @Published var latestHRV: Double?
    @Published var latestVO2Max: Double?
    @Published var todayWalkingDistance: Double?

    // MARK: - Computed Properties (Plan)

    var hasPlan: Bool { plannedWorkout != nil }
    var isRestDay: Bool { plannedWorkout?.type == "rest" }
    var isTrainingDay: Bool { plannedWorkout?.type == "training" }

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let sessionManager: ActiveSessionManager
    private let appDataState: AppDataState
    private let healthKitService: HealthKitServiceProtocol
    private(set) var hasLoaded = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, sessionManager: ActiveSessionManager, appDataState: AppDataState, healthKitService: HealthKitServiceProtocol) {
        self.networkService = networkService
        self.sessionManager = sessionManager
        self.appDataState = appDataState
        self.healthKitService = healthKitService

        sessionManager.$presentationState
            .removeDuplicates()
            .filter { $0 == .hidden }
            .dropFirst()
            .sink { [weak self] _ in
                self?.activeSession = nil
            }
            .store(in: &cancellables)

        appDataState.$reloadVersion
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadDashboard()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load If Needed

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadDashboard()
    }

    /// Called by BuildingPlanView to mark data as pre-loaded so HomeView skips its initial load
    func markAsLoaded() {
        hasLoaded = true
    }

    // MARK: - Computed Properties

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    var isShowingHistory: Bool {
        selectedDate != nil && sessionHistory != nil
    }

    var selectedDayLabel: String {
        guard let date = selectedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: - Data Loading

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await networkService.request(HomeRouter.dashboard.endpoint, responseType: DashboardResponse.self)
            userName = response.user.name
            avatarUrl = response.user.avatarUrl
            motivation = response.motivation
            // Convert API day-of-week (0=Sunday) to Monday-first index: (apiDay + 6) % 7
            weekCompletedDays = Set(response.weekCompletedDays.map { ($0 + 6) % 7 })
            quickWorkout = response.quickWorkout
            plannedWorkout = response.plannedWorkout
            weekWorkoutsTotal = response.weekWorkoutsTotal ?? 0
            weekWorkoutsCompleted = response.weekWorkoutsCompleted ?? 0
            weekVolumeKg = response.weekVolumeKg
            weekStreak = response.weekStreak
            weekAvgDurationMinutes = response.weekAvgDurationMinutes
            weekTotalCalories = response.weekTotalCalories
            todayCompletedSession = response.todayCompletedSession
            await loadCompletedDays()
            await loadHealthKitData()
        } catch {
            // Mock fallback for development
            userName = "Denys"
            quickWorkout = Self.mockQuickWorkout
            todayCompletedSession = nil
            errorMessage = nil
        }

        isLoading = false
    }

    private static var mockQuickWorkout: DashboardSession {
        DashboardSession(
            id: UUID().uuidString,
            title: "Active Recovery",
            type: "mobility",
            status: nil,
            durationMinutes: 25,
            aiMessage: "Since you don't have a plan today, I generated a light mobility session to keep you moving and aid recovery.",
            exercises: [
                DashboardExercise(id: UUID().uuidString, name: "Cat-Cow Stretches", stepNumber: 1, setsDisplay: "2 \u{00D7} 10", accentColor: "#E86A75", libraryExerciseId: nil, muscleGroup: "Core", equipment: "Bodyweight", suggestedWeight: nil, imageUrl: nil),
                DashboardExercise(id: UUID().uuidString, name: "Thoracic Rotations", stepNumber: 2, setsDisplay: "2 \u{00D7} 8", accentColor: "#30C08D", libraryExerciseId: nil, muscleGroup: "Back", equipment: "Bodyweight", suggestedWeight: nil, imageUrl: nil),
                DashboardExercise(id: UUID().uuidString, name: "Hip Flexor Stretch", stepNumber: 3, setsDisplay: "2 \u{00D7} 30", accentColor: "#7A82F6", libraryExerciseId: nil, muscleGroup: "Legs", equipment: "Bodyweight", suggestedWeight: nil, imageUrl: nil),
                DashboardExercise(id: UUID().uuidString, name: "90/90 Stretches", stepNumber: 4, setsDisplay: "2 \u{00D7} 10", accentColor: "#F5A623", libraryExerciseId: nil, muscleGroup: "Legs", equipment: "Bodyweight", suggestedWeight: nil, imageUrl: nil),
            ]
        )
    }

    // MARK: - Session Actions

    func startCustomSession() async {
        isStartingSession = true
        errorMessage = nil

        do {
            let response = try await networkService.request(
                HomeRouter.createSession(title: "Custom Session", type: "custom").endpoint,
                responseType: SessionResponse.self
            )
            sessionManager.openSession(response)
        } catch {
            // Mock fallback for development
            let mockResponse = SessionResponse(
                id: UUID().uuidString,
                title: "Custom Session",
                type: "custom",
                status: "active",
                startedAt: ISO8601DateFormatter().string(from: Date()),
                completedAt: nil,
                durationMinutes: nil,
                calories: nil,
                aiGenerated: false,
                aiMessage: nil,
                exercises: []
            )
            sessionManager.openSession(mockResponse)
            errorMessage = nil
        }

        isStartingSession = false
    }

    func startQuickWorkout() async {
        isStartingSession = true
        errorMessage = nil

        // If no quick workout from API, create a mock one
        guard let session = quickWorkout else {
            let mockResponse = SessionResponse(
                id: UUID().uuidString,
                title: "Quick Workout",
                type: "strength",
                status: "active",
                startedAt: ISO8601DateFormatter().string(from: Date()),
                completedAt: nil,
                durationMinutes: nil,
                calories: nil,
                aiGenerated: true,
                aiMessage: nil,
                exercises: []
            )
            sessionManager.openSession(mockResponse)
            isStartingSession = false
            return
        }

        do {
            let response = try await networkService.request(
                HomeRouter.startSession(sessionId: session.id).endpoint,
                responseType: SessionResponse.self
            )
            activeSession = response
            sessionManager.openSession(response)
            quickWorkout = nil
        } catch {
            // Mock fallback — open session flow with quick workout data
            let mockResponse = SessionResponse(
                id: session.id,
                title: session.title,
                type: session.type,
                status: "active",
                startedAt: ISO8601DateFormatter().string(from: Date()),
                completedAt: nil,
                durationMinutes: session.durationMinutes,
                calories: nil,
                aiGenerated: true,
                aiMessage: session.aiMessage,
                exercises: session.exercises
            )
            sessionManager.openSession(mockResponse)
            quickWorkout = nil
            errorMessage = nil
        }

        isStartingSession = false
    }

    func startPlannedWorkout() async {
        guard let planned = plannedWorkout, planned.type == "training",
              let dayId = planned.planDayId else { return }
        isStartingSession = true
        errorMessage = nil

        do {
            let response = try await networkService.request(
                PlanRouter.startPlanSession(dayId: dayId).endpoint,
                responseType: SessionResponse.self
            )
            sessionManager.openSession(response)
        } catch {
            // Mock fallback for development
            let mockResponse = SessionResponse(
                id: UUID().uuidString,
                title: planned.sessionTitle ?? "Training Session",
                type: planned.sessionType ?? "strength",
                status: "active",
                startedAt: ISO8601DateFormatter().string(from: Date()),
                completedAt: nil,
                durationMinutes: nil,
                calories: nil,
                aiGenerated: true,
                aiMessage: nil,
                exercises: []
            )
            sessionManager.openSession(mockResponse)
            errorMessage = nil
        }

        isStartingSession = false
    }

    func completeSession() async {
        guard let session = activeSession else { return }
        errorMessage = nil

        do {
            _ = try await networkService.request(
                HomeRouter.completeSession(sessionId: session.id).endpoint,
                responseType: SessionResponse.self
            )
            activeSession = nil
            // Reload dashboard to refresh week calendar and quick workout
            await loadDashboard()
        } catch {
            errorMessage = "Failed to complete session: \(error.localizedDescription)"
        }
    }

    // MARK: - History

    func selectDay(_ date: Date) {
        selectedDate = date
        Task {
            await loadHistory(for: date)
        }
    }

    func clearSelection() {
        selectedDate = nil
        sessionHistory = nil
    }

    func loadHistory(for date: Date) async {
        isLoadingHistory = true
        errorMessage = nil

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        do {
            let response = try await networkService.request(
                HomeRouter.history(date: dateString).endpoint,
                responseType: SessionHistoryResponse.self
            )
            sessionHistory = response.session
        } catch {
            // For now, load mock data since the API isn't built yet
            sessionHistory = Self.mockSessionHistory
            errorMessage = nil // Suppress error while using mock data
        }

        isLoadingHistory = false
    }

    func loadCompletedDays() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthString = formatter.string(from: Date())

        do {
            let response = try await networkService.request(
                HomeRouter.completedDays(month: monthString).endpoint,
                responseType: CompletedDaysResponse.self
            )
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone.current
            completedDates = Set(response.completedDates.compactMap { dateFormatter.date(from: $0) })
        } catch {
            // Silently fail — calendar will just not show dots
        }
    }

    private func loadHealthKitData() async {
        guard healthKitService.isHealthDataAvailable else { return }
        do {
            try await healthKitService.requestAuthorization()
        } catch {
            return
        }

        let startOfToday = Calendar.current.startOfDay(for: Date())
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()

        async let weightResult = healthKitService.fetchLatestWeight()
        async let hrResult = healthKitService.fetchRestingHeartRate()
        async let energyResult = healthKitService.fetchTotalActiveEnergy(from: startOfToday, to: endOfToday)
        async let bodyFatResult = healthKitService.fetchLatestBodyFat()
        async let leanMassResult = healthKitService.fetchLatestLeanBodyMass()
        async let stepsResult = healthKitService.fetchTodayStepCount()
        async let sleepResult = healthKitService.fetchLastNightSleepDuration()
        async let hrvResult = healthKitService.fetchLatestHRV()
        async let vo2Result = healthKitService.fetchLatestVO2Max()
        async let distanceResult = healthKitService.fetchTodayWalkingDistance()

        latestWeightKg = try? await weightResult?.value
        restingHeartRate = try? await hrResult
        todayActiveEnergy = try? await energyResult
        latestBodyFat = try? await bodyFatResult
        latestLeanBodyMass = try? await leanMassResult
        todayStepCount = try? await stepsResult
        lastNightSleep = try? await sleepResult
        latestHRV = try? await hrvResult
        latestVO2Max = try? await vo2Result
        todayWalkingDistance = try? await distanceResult
    }

    private static var mockSessionHistory: SessionHistory {
        SessionHistory(
            id: "mock-1",
            sessionIds: ["mock-1"],
            title: "Mon's Session",
            type: "strength",
            durationMinutes: 52,
            calories: 385,
            performanceScore: 87,
            exercises: [
                HistoryExercise(
                    id: "ex-1",
                    name: "Barbell Bench Press",
                    muscleGroup: "Chest",
                    accentColor: "#E86A75",
                    stepNumber: 1,
                    sets: [
                        ExerciseSetData(setNumber: 1, weight: 185, weightUnit: "lbs", reps: 8),
                        ExerciseSetData(setNumber: 2, weight: 185, weightUnit: "lbs", reps: 8),
                        ExerciseSetData(setNumber: 3, weight: 185, weightUnit: "lbs", reps: 7),
                        ExerciseSetData(setNumber: 4, weight: 185, weightUnit: "lbs", reps: 6),
                    ]
                ),
                HistoryExercise(
                    id: "ex-2",
                    name: "Incline Dumbbell Press",
                    muscleGroup: "Chest",
                    accentColor: "#30C08D",
                    stepNumber: 2,
                    sets: [
                        ExerciseSetData(setNumber: 1, weight: 60, weightUnit: "lbs", reps: 10),
                        ExerciseSetData(setNumber: 2, weight: 60, weightUnit: "lbs", reps: 9),
                        ExerciseSetData(setNumber: 3, weight: 60, weightUnit: "lbs", reps: 8),
                    ]
                ),
                HistoryExercise(
                    id: "ex-3",
                    name: "Pull-ups",
                    muscleGroup: "Back",
                    accentColor: "#7A82F6",
                    stepNumber: 3,
                    sets: [
                        ExerciseSetData(setNumber: 1, weight: nil, weightUnit: "lbs", reps: 12),
                        ExerciseSetData(setNumber: 2, weight: nil, weightUnit: "lbs", reps: 10),
                        ExerciseSetData(setNumber: 3, weight: nil, weightUnit: "lbs", reps: 9),
                        ExerciseSetData(setNumber: 4, weight: nil, weightUnit: "lbs", reps: 8),
                    ]
                ),
                HistoryExercise(
                    id: "ex-4",
                    name: "Overhead Press",
                    muscleGroup: "Shoulders",
                    accentColor: "#F5A623",
                    stepNumber: 4,
                    sets: [
                        ExerciseSetData(setNumber: 1, weight: 95, weightUnit: "lbs", reps: 8),
                        ExerciseSetData(setNumber: 2, weight: 95, weightUnit: "lbs", reps: 8),
                        ExerciseSetData(setNumber: 3, weight: 95, weightUnit: "lbs", reps: 7),
                    ]
                ),
            ]
        )
    }
}
