//
//  OnboardingData.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation

/// Complete onboarding data collected from user
struct OnboardingData: Codable, Equatable {
    var primaryGoals: [PrimaryGoal]
    var primarySports: [String]
    var experienceLevel: ExperienceLevel?
    var weightKg: Double?
    var heightCm: Double?
    var biologicalSex: BiologicalSex?
    var trainingFrequency: TrainingFrequency?
    var workoutDuration: WorkoutDuration?
    var preferredRestTime: RestTime?
    var availableEquipment: Equipment?
    var injuries: [InjuryType] // Array for multi-select
    var completedAt: Date?

    init() {
        self.primaryGoals = []
        self.primarySports = []
        self.injuries = []
    }

    /// Check if onboarding is complete
    var isComplete: Bool {
        return !primaryGoals.isEmpty &&
               !primarySports.isEmpty &&
               experienceLevel != nil &&
               trainingFrequency != nil &&
               workoutDuration != nil &&
               availableEquipment != nil
        // Note: injuries can be empty (user selected "None")
    }

    /// Convert to JSON for Supabase
    func toSupabaseJSON() -> [String: Any] {
        var json: [String: Any] = [:]

        if !primaryGoals.isEmpty {
            json["primary_goals"] = primaryGoals.map { $0.rawValue }
        }
        if !primarySports.isEmpty {
            json["primary_sports"] = primarySports
        }
        if let level = experienceLevel {
            json["experience_level"] = level.rawValue
        }
        if let frequency = trainingFrequency {
            json["training_frequency"] = frequency.days
        }
        if let duration = workoutDuration {
            json["workout_duration"] = duration.minutes
        }
        if let restTime = preferredRestTime {
            json["preferred_rest_time"] = restTime.rawValue
        }
        if let equipment = availableEquipment {
            json["available_equipment"] = equipment.rawValue
        }
        if let weight = weightKg {
            json["weight_kg"] = weight
        }
        if let height = heightCm {
            json["height_cm"] = height
        }
        if let sex = biologicalSex {
            json["biological_sex"] = sex.rawValue
        }

        // Convert injuries to JSON array
        json["injuries"] = injuries.map { injury in
            if case .custom(let text) = injury {
                return ["type": "custom", "value": text]
            } else {
                return ["type": injury.rawValue, "value": injury.displayName]
            }
        }

        if let completed = completedAt {
            json["completed_at"] = ISO8601DateFormatter().string(from: completed)
        }

        return json
    }
}

// MARK: - Biological Sex

enum BiologicalSex: String, Codable, CaseIterable, Equatable {
    case male
    case female
    case other

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        case .other: return "person.fill"
        }
    }
}

// MARK: - Primary Goal

enum PrimaryGoal: String, Codable, CaseIterable {
    case buildMuscle = "build_muscle"
    case loseFat = "lose_fat"
    case recomposition = "recomposition"
    case improveEndurance = "improve_endurance"
    case generalFitness = "general_fitness"

    var displayName: String {
        switch self {
        case .buildMuscle: return "Build Muscle"
        case .loseFat: return "Lose Fat"
        case .recomposition: return "Recomposition"
        case .improveEndurance: return "Improve Endurance"
        case .generalFitness: return "General Fitness"
        }
    }
}

// MARK: - Experience Level

enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return "0-1 yrs"
        case .intermediate: return "1-3 yrs"
        case .advanced: return "3+ yrs"
        }
    }
}

// MARK: - Training Frequency

enum TrainingFrequency: Int, Codable, CaseIterable {
    case oneDay = 1
    case twoDays = 2
    case threeDays = 3
    case fourDays = 4
    case fiveDays = 5
    case sixDays = 6
    case sevenDays = 7

    var days: Int {
        return rawValue
    }

    var displayName: String {
        switch self {
        case .oneDay: return "Sunday Warrior"
        case .twoDays: return "Weekend Warrior"
        case .threeDays: return "Three-Plate Special"
        case .fourDays: return "The Dedicated"
        case .fiveDays: return "Gym Rat"
        case .sixDays: return "Iron Addict"
        case .sevenDays: return "No Rest For The Wicked"
        }
    }

    var label: String {
        return "\(days) Day\(days > 1 ? "s" : "")"
    }
}

// MARK: - Workout Duration

enum WorkoutDuration: Int, Codable, CaseIterable {
    case thirty = 30
    case fortyFive = 45
    case sixty = 60
    case ninety = 90

    var minutes: Int {
        return rawValue
    }

    var displayName: String {
        if self == .ninety {
            return "90+ minutes"
        }
        return "\(minutes) minutes"
    }
}

// MARK: - Rest Time

enum RestTime: Int, Codable, CaseIterable {
    case thirty = 30
    case sixty = 60
    case ninety = 90
    case onetwenty = 120
    case onefifty = 150
    case oneeighty = 180
    case twoten = 210
    case twofourty = 240
    case twoseventy = 270
    case threehundred = 300

    var displayName: String {
        let minutes = rawValue / 60
        let seconds = rawValue % 60
        if minutes == 0 {
            return "\(seconds) seconds"
        } else if seconds == 0 {
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        } else {
            return "\(minutes) min \(seconds) sec"
        }
    }
}

// MARK: - Available Equipment

enum Equipment: String, Codable, CaseIterable {
    case fullGym = "full_gym"
    case dumbbellsOnly = "dumbbells_only"
    case bodyweight = "bodyweight"
    case homeGym = "home_gym"

    var displayName: String {
        switch self {
        case .fullGym: return "Full Gym"
        case .dumbbellsOnly: return "Dumbbells Only"
        case .bodyweight: return "Bodyweight"
        case .homeGym: return "Home Gym"
        }
    }
}

// MARK: - Injury Type

enum InjuryType: Codable, Equatable, Hashable {
    case none
    case shoulders
    case lowerBack
    case knees
    case wrists
    case custom(String)

    var displayName: String {
        switch self {
        case .none: return "None"
        case .shoulders: return "Shoulders / Rotator Cuff"
        case .lowerBack: return "Lower Back"
        case .knees: return "Knees"
        case .wrists: return "Wrists"
        case .custom(let text): return text
        }
    }

    var rawValue: String {
        switch self {
        case .none: return "none"
        case .shoulders: return "shoulders"
        case .lowerBack: return "lower_back"
        case .knees: return "knees"
        case .wrists: return "wrists"
        case .custom: return "custom"
        }
    }

    // Static cases for selection UI
    static var standardCases: [InjuryType] {
        [.none, .shoulders, .lowerBack, .knees, .wrists]
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "none": self = .none
        case "shoulders": self = .shoulders
        case "lower_back": self = .lowerBack
        case "knees": self = .knees
        case "wrists": self = .wrists
        case "custom":
            let value = try container.decode(String.self, forKey: .value)
            self = .custom(value)
        default:
            self = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .none:
            try container.encode("none", forKey: .type)
        case .shoulders:
            try container.encode("shoulders", forKey: .type)
        case .lowerBack:
            try container.encode("lower_back", forKey: .type)
        case .knees:
            try container.encode("knees", forKey: .type)
        case .wrists:
            try container.encode("wrists", forKey: .type)
        case .custom(let text):
            try container.encode("custom", forKey: .type)
            try container.encode(text, forKey: .value)
        }
    }
}

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable {
    case authentication = 1
    case primaryGoal = 2
    case primarySport = 3
    case experienceLevel = 4
    case bodyMetrics = 5
    case trainingFrequency = 6
    case workoutDuration = 7
    case restTime = 8
    case equipment = 9
    case injuries = 10
    case completeProfile = 11

    var title: String {
        switch self {
        case .authentication: return "Create your account"
        case .primaryGoal: return "What is your primary goal?"
        case .primarySport: return "What is your primary sport?"
        case .experienceLevel: return "What is your experience level?"
        case .bodyMetrics: return "About you"
        case .trainingFrequency: return "Weekly workout goal"
        case .workoutDuration: return "Preferred workout duration?"
        case .restTime: return "Preferred rest between sets?"
        case .equipment: return "Available equipment?"
        case .injuries: return "Any current injuries?"
        case .completeProfile: return "Complete Your Profile"
        }
    }

    var iconName: String {
        switch self {
        case .authentication: return "person.circle.fill"
        case .primaryGoal: return "target"
        case .primarySport: return "figure.run"
        case .experienceLevel: return "dumbbell.fill"
        case .bodyMetrics: return "figure.arms.open"
        case .trainingFrequency: return "calendar"
        case .workoutDuration: return "clock.fill"
        case .restTime: return "timer"
        case .equipment: return "dumbbell.fill"
        case .injuries: return "exclamationmark.triangle.fill"
        case .completeProfile: return "person.crop.circle.fill"
        }
    }

    var totalSteps: Int {
        return OnboardingStep.allCases.count
    }

    var progressPercentage: Double {
        return Double(rawValue) / Double(totalSteps)
    }
}
