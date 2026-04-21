//
//  SubscriptionModels.swift
//  GymBro
//

import Foundation

struct SubscriptionStatusResponse: Decodable {
    let isPremium: Bool
    let premiumSource: String?
    let grantedAt: String?
    let expiresAt: String?
    let productId: String?
    let coachMessagesUsed: Int
    let coachMessagesLimit: Int?
}

enum PremiumFeature: String {
    case coachChat = "coach_chat"
    case customExercises = "custom_exercises"
    case supersets = "supersets"
    case planGeneration = "plan_generation"

    var displayName: String {
        switch self {
        case .coachChat: return "AI Coach"
        case .customExercises: return "Custom Exercises"
        case .supersets: return "Supersets"
        case .planGeneration: return "Plan Generation"
        }
    }
}
