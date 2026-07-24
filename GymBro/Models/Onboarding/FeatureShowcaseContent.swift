//
//  FeatureShowcaseContent.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation

/// Static content for feature showcase onboarding screens
struct FeatureShowcaseContent {
    let title: String
    let iconName: String
    let imageName: String
    let description: String
    let features: [(icon: String, title: String, subtitle: String)]
}

// MARK: - Static Instances

extension FeatureShowcaseContent {

    static let trackEveryRep = FeatureShowcaseContent(
        title: String(localized: "Track Every Rep"),
        iconName: "house.fill",
        imageName: "showcase-track",
        description: String(localized: "Your personal workout dashboard with live stats, performance insights, and AI-powered recommendations."),
        features: [
            (icon: "chart.bar.fill", title: String(localized: "Live Progress Tracking"), subtitle: String(localized: "See your gains in real-time with volume, PRs, and strength trends")),
            (icon: "timer", title: String(localized: "Smart Rest Timer"), subtitle: String(localized: "Automatically start rest timers between sets with custom durations")),
            (icon: "bolt.fill", title: String(localized: "Quick Start Workouts"), subtitle: String(localized: "Jump into your routine or start a custom session in seconds")),
        ]
    )

    static let personalizedPlans = FeatureShowcaseContent(
        title: String(localized: "Personalized Plans"),
        iconName: "calendar",
        imageName: "showcase-plans",
        description: String(localized: "AI-generated workout programs tailored to your goals, experience, and available equipment."),
        features: [
            (icon: "target", title: String(localized: "Goal-Based Programming"), subtitle: String(localized: "Plans built around muscle building, fat loss, or performance")),
            (icon: "calendar.badge.clock", title: String(localized: "Weekly Scheduling"), subtitle: String(localized: "Adaptive routines that fit your lifestyle and availability")),
            (icon: "book.fill", title: String(localized: "Exercise Library"), subtitle: String(localized: "500+ exercises with form videos and muscle group targeting")),
        ]
    )

    static let aiCoach = FeatureShowcaseContent(
        title: String(localized: "AI Coach 24/7"),
        iconName: "bubble.left.fill",
        imageName: "showcase-coach",
        description: String(localized: "Get instant answers about form, nutrition, programming, and recovery from your personal AI coach."),
        features: [
            (icon: "brain.head.profile", title: String(localized: "Contextual Advice"), subtitle: String(localized: "AI that knows your workout history, goals, and current progress")),
            (icon: "bolt.horizontal.fill", title: String(localized: "Instant Responses"), subtitle: String(localized: "No waiting - get expert guidance whenever you need it")),
            (icon: "figure.strengthtraining.traditional", title: String(localized: "Form & Technique"), subtitle: String(localized: "Detailed breakdowns of proper exercise execution")),
        ]
    )

    static let trainTogether = FeatureShowcaseContent(
        title: String(localized: "Train Together"),
        iconName: "person.3.fill",
        imageName: "showcase-community",
        description: String(localized: "Share your workouts, celebrate PRs, and stay motivated with a community of like-minded lifters."),
        features: [
            (icon: "square.and.arrow.up.fill", title: String(localized: "Workout Sharing"), subtitle: String(localized: "Post your sessions with exercises, sets, and total volume")),
            (icon: "trophy.fill", title: String(localized: "Celebrate PRs"), subtitle: String(localized: "Hit a new max? Share it and get support from the community")),
            (icon: "chart.line.uptrend.xyaxis", title: String(localized: "Leaderboards"), subtitle: String(localized: "See how you stack up in strength and consistency")),
        ]
    )
}
