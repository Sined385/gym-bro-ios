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
        title: "Track Every Rep",
        iconName: "house.fill",
        imageName: "showcase-track",
        description: "Your personal workout dashboard with live stats, performance insights, and AI-powered recommendations.",
        features: [
            (icon: "chart.bar.fill", title: "Live Progress Tracking", subtitle: "See your gains in real-time with volume, PRs, and strength trends"),
            (icon: "timer", title: "Smart Rest Timer", subtitle: "Automatically start rest timers between sets with custom durations"),
            (icon: "bolt.fill", title: "Quick Start Workouts", subtitle: "Jump into your routine or start a custom session in seconds"),
        ]
    )

    static let personalizedPlans = FeatureShowcaseContent(
        title: "Personalized Plans",
        iconName: "calendar",
        imageName: "showcase-plans",
        description: "AI-generated workout programs tailored to your goals, experience, and available equipment.",
        features: [
            (icon: "target", title: "Goal-Based Programming", subtitle: "Plans built around muscle building, fat loss, or performance"),
            (icon: "calendar.badge.clock", title: "Weekly Scheduling", subtitle: "Adaptive routines that fit your lifestyle and availability"),
            (icon: "book.fill", title: "Exercise Library", subtitle: "500+ exercises with form videos and muscle group targeting"),
        ]
    )

    static let aiCoach = FeatureShowcaseContent(
        title: "AI Coach 24/7",
        iconName: "bubble.left.fill",
        imageName: "showcase-coach",
        description: "Get instant answers about form, nutrition, programming, and recovery from your personal AI coach.",
        features: [
            (icon: "brain.head.profile", title: "Contextual Advice", subtitle: "AI that knows your workout history, goals, and current progress"),
            (icon: "bolt.horizontal.fill", title: "Instant Responses", subtitle: "No waiting - get expert guidance whenever you need it"),
            (icon: "figure.strengthtraining.traditional", title: "Form & Technique", subtitle: "Detailed breakdowns of proper exercise execution"),
        ]
    )

    static let trainTogether = FeatureShowcaseContent(
        title: "Train Together",
        iconName: "person.3.fill",
        imageName: "showcase-community",
        description: "Share your workouts, celebrate PRs, and stay motivated with a community of like-minded lifters.",
        features: [
            (icon: "square.and.arrow.up.fill", title: "Workout Sharing", subtitle: "Post your sessions with exercises, sets, and total volume"),
            (icon: "trophy.fill", title: "Celebrate PRs", subtitle: "Hit a new max? Share it and get support from the community"),
            (icon: "chart.line.uptrend.xyaxis", title: "Leaderboards", subtitle: "See how you stack up in strength and consistency"),
        ]
    )
}
