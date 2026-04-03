//
//  ExerciseLibraryViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import Foundation
import Combine

@MainActor
final class ExerciseLibraryViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var exercises: [ExerciseLibraryItem] = []
    @Published var searchText: String = ""
    @Published var selectedMuscleGroup: MuscleGroup? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let analyticsService: AnalyticsTrackingServiceProtocol

    // MARK: - Computed Properties

    var filteredExercises: [ExerciseLibraryItem] {
        var result = exercises

        if let group = selectedMuscleGroup {
            result = result.filter { $0.muscleGroup == group.rawValue }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, analyticsService: AnalyticsTrackingServiceProtocol) {
        self.networkService = networkService
        self.analyticsService = analyticsService
    }

    // MARK: - Data Loading

    func loadExercises() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await networkService.request(ExerciseRouter.list.endpoint, responseType: ExerciseLibraryResponse.self)
            exercises = response.exercises
        } catch {
            exercises = Self.mockExercises
        }

        isLoading = false
    }

    // MARK: - Create Custom Exercise

    func createCustomExercise(name: String, muscleGroup: String, equipment: String) async -> ExerciseLibraryItem? {
        isLoading = true
        errorMessage = nil

        do {
            let item = try await networkService.request(
                ExerciseRouter.create(name: name, muscleGroup: muscleGroup, equipment: equipment).endpoint,
                responseType: ExerciseLibraryItem.self
            )
            exercises.append(item)
            analyticsService.track("custom_exercise_created", properties: ["name": name, "muscle_group": muscleGroup])
            isLoading = false
            return item
        } catch {
            // Mock fallback
            let mockItem = ExerciseLibraryItem(
                id: UUID().uuidString,
                name: name,
                muscleGroup: muscleGroup,
                equipment: equipment,
                isSystem: false
            )
            exercises.append(mockItem)
            isLoading = false
            return mockItem
        }
    }

    // MARK: - Mock Data

    private static let mockExercises: [ExerciseLibraryItem] = [
        // MARK: Chest — BW:5, DB:5, BB:4, Cable:2, Machine:2 = 18
        ExerciseLibraryItem(id: "lib-1", name: "Barbell Bench Press", muscleGroup: "Chest", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-2", name: "Incline Dumbbell Press", muscleGroup: "Chest", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-3", name: "Cable Fly", muscleGroup: "Chest", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-4", name: "Dumbbell Bench Press", muscleGroup: "Chest", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-5", name: "Incline Barbell Press", muscleGroup: "Chest", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-6", name: "Decline Bench Press", muscleGroup: "Chest", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-7", name: "Chest Dip", muscleGroup: "Chest", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-8", name: "Push-up", muscleGroup: "Chest", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-9", name: "Pec Deck Machine", muscleGroup: "Chest", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-10", name: "Dumbbell Fly", muscleGroup: "Chest", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-11", name: "Machine Chest Press", muscleGroup: "Chest", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-12", name: "Landmine Press", muscleGroup: "Chest", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-13", name: "Cable Crossover", muscleGroup: "Chest", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-14", name: "Dumbbell Pullover", muscleGroup: "Chest", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-15", name: "Decline Dumbbell Press", muscleGroup: "Chest", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-16", name: "Wide Push-up", muscleGroup: "Chest", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-17", name: "Decline Push-up", muscleGroup: "Chest", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-18", name: "Archer Push-up", muscleGroup: "Chest", equipment: "Bodyweight", isSystem: true),

        // MARK: Back — BW:4, DB:4, BB:5, Cable:4, Machine:1 = 18
        ExerciseLibraryItem(id: "lib-19", name: "Pull-up", muscleGroup: "Back", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-20", name: "Barbell Row", muscleGroup: "Back", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-21", name: "Lat Pulldown", muscleGroup: "Back", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-22", name: "Deadlift", muscleGroup: "Back", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-23", name: "Seated Cable Row", muscleGroup: "Back", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-24", name: "Dumbbell Row", muscleGroup: "Back", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-25", name: "T-Bar Row", muscleGroup: "Back", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-26", name: "Chin-up", muscleGroup: "Back", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-27", name: "Face Pull", muscleGroup: "Back", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-28", name: "Pendlay Row", muscleGroup: "Back", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-29", name: "Machine Row", muscleGroup: "Back", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-30", name: "Straight Arm Pulldown", muscleGroup: "Back", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-31", name: "Inverted Row", muscleGroup: "Back", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-32", name: "Rack Pull", muscleGroup: "Back", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-33", name: "Renegade Row", muscleGroup: "Back", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-34", name: "Dumbbell Shrug", muscleGroup: "Back", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-35", name: "Dumbbell Reverse Fly", muscleGroup: "Back", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-36", name: "Superman", muscleGroup: "Back", equipment: "Bodyweight", isSystem: true),

        // MARK: Legs — BW:6, DB:5, BB:5, Machine:4 = 20
        ExerciseLibraryItem(id: "lib-37", name: "Barbell Squat", muscleGroup: "Legs", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-38", name: "Romanian Deadlift", muscleGroup: "Legs", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-39", name: "Leg Press", muscleGroup: "Legs", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-40", name: "Bulgarian Split Squat", muscleGroup: "Legs", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-41", name: "Leg Extension", muscleGroup: "Legs", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-42", name: "Leg Curl", muscleGroup: "Legs", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-43", name: "Walking Lunge", muscleGroup: "Legs", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-44", name: "Goblet Squat", muscleGroup: "Legs", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-45", name: "Hip Thrust", muscleGroup: "Legs", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-46", name: "Front Squat", muscleGroup: "Legs", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-47", name: "Hack Squat", muscleGroup: "Legs", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-48", name: "Standing Calf Raise", muscleGroup: "Legs", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-49", name: "Sumo Deadlift", muscleGroup: "Legs", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-50", name: "Dumbbell Step-up", muscleGroup: "Legs", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-51", name: "Glute Bridge", muscleGroup: "Legs", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-52", name: "Bodyweight Squat", muscleGroup: "Legs", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-53", name: "Pistol Squat", muscleGroup: "Legs", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-54", name: "Jump Squat", muscleGroup: "Legs", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-55", name: "Wall Sit", muscleGroup: "Legs", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-56", name: "Reverse Lunge", muscleGroup: "Legs", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-57", name: "Dumbbell Romanian Deadlift", muscleGroup: "Legs", equipment: "Dumbbells", isSystem: true),

        // MARK: Shoulders — BW:4, DB:6, BB:3, Cable:2, Machine:2 = 17
        ExerciseLibraryItem(id: "lib-58", name: "Overhead Press", muscleGroup: "Shoulders", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-59", name: "Lateral Raise", muscleGroup: "Shoulders", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-60", name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-61", name: "Arnold Press", muscleGroup: "Shoulders", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-62", name: "Front Raise", muscleGroup: "Shoulders", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-63", name: "Reverse Fly", muscleGroup: "Shoulders", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-64", name: "Cable Lateral Raise", muscleGroup: "Shoulders", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-65", name: "Upright Row", muscleGroup: "Shoulders", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-66", name: "Machine Shoulder Press", muscleGroup: "Shoulders", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-67", name: "Rear Delt Fly Machine", muscleGroup: "Shoulders", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-68", name: "Push Press", muscleGroup: "Shoulders", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-69", name: "Lu Raise", muscleGroup: "Shoulders", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-70", name: "Pike Push-up", muscleGroup: "Shoulders", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-71", name: "Handstand Push-up", muscleGroup: "Shoulders", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-72", name: "Wall Walk", muscleGroup: "Shoulders", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-73", name: "Bodyweight Y Raise", muscleGroup: "Shoulders", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-74", name: "Cable Face Pull", muscleGroup: "Shoulders", equipment: "Cable", isSystem: true),

        // MARK: Arms — BW:4, DB:6, BB:4, Cable:3 = 17
        ExerciseLibraryItem(id: "lib-75", name: "Barbell Curl", muscleGroup: "Arms", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-76", name: "Dumbbell Curl", muscleGroup: "Arms", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-77", name: "Tricep Pushdown", muscleGroup: "Arms", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-78", name: "Hammer Curl", muscleGroup: "Arms", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-79", name: "Skull Crusher", muscleGroup: "Arms", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-80", name: "Preacher Curl", muscleGroup: "Arms", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-81", name: "Overhead Tricep Extension", muscleGroup: "Arms", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-82", name: "Cable Curl", muscleGroup: "Arms", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-83", name: "Tricep Dip", muscleGroup: "Arms", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-84", name: "Concentration Curl", muscleGroup: "Arms", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-85", name: "Close-Grip Bench Press", muscleGroup: "Arms", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-86", name: "Incline Dumbbell Curl", muscleGroup: "Arms", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-87", name: "Tricep Kickback", muscleGroup: "Arms", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-88", name: "Wrist Curl", muscleGroup: "Arms", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-89", name: "Diamond Push-up", muscleGroup: "Arms", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-90", name: "Bench Dip", muscleGroup: "Arms", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-91", name: "Chin-up Close Grip", muscleGroup: "Arms", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-92", name: "Overhead Cable Extension", muscleGroup: "Arms", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-93", name: "Dumbbell Zottman Curl", muscleGroup: "Arms", equipment: "Dumbbells", isSystem: true),

        // MARK: Core — BW:10, Cable:2, DB:2 = 14
        ExerciseLibraryItem(id: "lib-94", name: "Plank", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-95", name: "Hanging Leg Raise", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-96", name: "Cable Crunch", muscleGroup: "Core", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-97", name: "Ab Wheel Rollout", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-98", name: "Russian Twist", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-99", name: "Bicycle Crunch", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-100", name: "Mountain Climber", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-101", name: "Dead Bug", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-102", name: "V-up", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-103", name: "Pallof Press", muscleGroup: "Core", equipment: "Cable", isSystem: true),
        ExerciseLibraryItem(id: "lib-104", name: "Decline Sit-up", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-105", name: "Side Plank", muscleGroup: "Core", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-106", name: "Dumbbell Woodchop", muscleGroup: "Core", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-107", name: "Weighted Sit-up", muscleGroup: "Core", equipment: "Dumbbells", isSystem: true),

        // MARK: Other — BW:5, DB:3, BB:1, Machine:2 = 11
        ExerciseLibraryItem(id: "lib-108", name: "Farmer's Walk", muscleGroup: "Other", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-109", name: "Battle Ropes", muscleGroup: "Other", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-110", name: "Box Jump", muscleGroup: "Other", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-111", name: "Kettlebell Swing", muscleGroup: "Other", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-112", name: "Sled Push", muscleGroup: "Other", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-113", name: "Turkish Get-up", muscleGroup: "Other", equipment: "Dumbbells", isSystem: true),
        ExerciseLibraryItem(id: "lib-114", name: "Clean and Press", muscleGroup: "Other", equipment: "Barbell", isSystem: true),
        ExerciseLibraryItem(id: "lib-115", name: "Burpee", muscleGroup: "Other", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-116", name: "Bear Crawl", muscleGroup: "Other", equipment: "Bodyweight", isSystem: true),
        ExerciseLibraryItem(id: "lib-117", name: "Rowing Machine", muscleGroup: "Other", equipment: "Machine", isSystem: true),
        ExerciseLibraryItem(id: "lib-118", name: "Jumping Jack", muscleGroup: "Other", equipment: "Bodyweight", isSystem: true),
    ]
}
