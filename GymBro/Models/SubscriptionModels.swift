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

struct SyncResponse: Decodable {
    let isPremium: Bool
}

/// 200-envelope from POST /subscription/promo/redeem. Errors ride in
/// the body (success=false + message) because NetworkService drops
/// 4xx response bodies.
struct PromoRedeemResponse: Decodable {
    let success: Bool
    let expiresAt: String?
    let durationDays: Int?
    let errorCode: String?
    let message: String?
}

enum PremiumFeature: String {
    case coachChat = "coach_chat"
    case customExercises = "custom_exercises"
    case supersets = "supersets"
    case planGeneration = "plan_generation"
    case profileComparison = "profile_comparison"

    var displayName: String {
        switch self {
        case .coachChat: return "AI Coach"
        case .customExercises: return "Custom Exercises"
        case .supersets: return "Supersets"
        case .planGeneration: return "Plan Generation"
        case .profileComparison: return "AI Comparison"
        }
    }
}
