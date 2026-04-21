//
//  CommunityModels.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import Foundation

// MARK: - Post

struct CommunityPost: Decodable, Identifiable, Equatable {
    let id: String
    let user: PostUser
    let content: String
    let visibility: String
    let photoUrl: String?
    let workoutAttachment: WorkoutAttachment?
    let likeCount: Int
    let commentCount: Int
    let isLiked: Bool
    let isFollowingAuthor: Bool
    let isOwnPost: Bool
    let createdAt: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
        lhs.likeCount == rhs.likeCount &&
        lhs.commentCount == rhs.commentCount &&
        lhs.isLiked == rhs.isLiked &&
        lhs.isFollowingAuthor == rhs.isFollowingAuthor
    }
}

struct PostUser: Decodable, Equatable {
    let id: String
    let fullName: String
    let username: String?
    let avatarUrl: String?
}

// MARK: - Workout Attachment

struct WorkoutAttachment: Decodable, Equatable {
    let sessionId: String
    let title: String
    let durationMinutes: Int?
    let exerciseCount: Int
    let aiGenerated: Bool?
    let rpe: Int?
    let exercises: [AttachmentExercise]?
}

struct AttachmentSetData: Decodable, Equatable, Identifiable {
    let setNumber: Int
    let weight: Double?
    let weightUnit: String?
    let reps: Int
    var id: Int { setNumber }
}

struct AttachmentExercise: Decodable, Equatable, Identifiable {
    let name: String
    let muscleGroup: String?
    let stepNumber: Int?
    let setsDisplay: String?
    let accentColor: String?
    let totalSets: Int
    let totalReps: Int
    let imageUrl: String?
    let externalId: String?
    let sets: [AttachmentSetData]?
    let supersetGroupId: String?
    let supersetOrder: String?
    var id: String { name }
}

// MARK: - Feed Response

struct FeedResponse: Decodable {
    let posts: [CommunityPost]
    let nextCursor: String?
    let hasMore: Bool
}

// MARK: - Comments

struct PostComment: Decodable, Identifiable, Equatable {
    let id: String
    let user: PostUser
    let content: String
    let createdAt: String
}

struct CommentsResponse: Decodable {
    let comments: [PostComment]
    let nextCursor: String?
    let hasMore: Bool
}

// MARK: - Like Response

struct LikeResponse: Decodable {
    let isLiked: Bool
    let likeCount: Int
}

// MARK: - Follow Response

struct FollowResponse: Decodable {
    let followId: String?
    let message: String?
}

// MARK: - User Profile

struct UserProfile: Decodable {
    let user: PostUser
    let primaryGoals: [String]?
    let experienceLevel: String?
    let bodyWeightKg: Double?
    let memberSince: String?
    let consistencyStats: ConsistencyStats
    let extendedStats: ExtendedStats?
    let followerCount: Int?
    let followingCount: Int?
    let isFollowing: Bool
    let followsMe: Bool
    let recentPosts: [CommunityPost]
    let isOwnProfile: Bool
}

struct ConsistencyStats: Decodable {
    let totalSessions: Int
    let last30DaysSessions: Int
    let thisWeek: Int?
    let thisMonth: Int?
    let thisYear: Int?
}

// MARK: - My Profile

struct MyProfileResponse: Decodable {
    let user: PostUser
    let primaryGoals: [String]?
    let experienceLevel: String?
    let bodyWeightKg: Double?
    let memberSince: String
    let consistencyStats: ConsistencyStats
    let extendedStats: ExtendedStats
    let followerCount: Int
    let followingCount: Int
    let recentPosts: [CommunityPost]
}

struct ExtendedStats: Decodable {
    let totalDurationMinutes: Int
    let totalCalories: Int
    let avgSessionDuration: Int
    let avgEffortLevel: Double?
    let totalWeightLifted: Double
    let personalRecords: [PersonalRecord]
}

struct PersonalRecord: Decodable, Identifiable {
    let exerciseName: String
    let weight: Double
    let weightUnit: String
    let reps: Int
    let date: String?
    var id: String { exerciseName }
}

// MARK: - Profile Workouts

struct ProfileWorkoutsResponse: Decodable {
    let workouts: [ProfileWorkout]
    let nextCursor: String?
    let hasMore: Bool
}

struct ProfileWorkout: Decodable, Identifiable {
    let id: String
    let title: String
    let type: String
    let durationMinutes: Int?
    let calories: Int?
    let completedAt: String
    let exercises: [HistoryExercise]
}

// MARK: - AI Comparison

struct AiComparison: Decodable {
    let currentUser: LiftStats
    let otherUser: LiftStats
    let comparison: ComparisonAnalysis?
    let overlapAnalysis: String?
}

struct LiftStats: Decodable {
    let userId: String
    let fullName: String
    let benchPress: Double?
    let squat: Double?
    let deadlift: Double?
    let bodyWeightKg: Double?
    let experienceLevel: String?
    let primaryGoals: [String]?
    let totalSessions3mo: Int?
    let avgSessionsPerWeek: Double?
    let avgSessionDurationMin: Int?
    let topMuscleGroups: [String]?
    let avgEffortLevel: Double?
    let volumeTrend: String?
}

struct ComparisonAnalysis: Decodable {
    let summary: String
    let trainingPatterns: String
    let volumeTrends: String
    let strengths: ComparisonStrengths
    let recommendation: String
}

struct ComparisonStrengths: Decodable {
    let currentUser: String
    let otherUser: String
}

// MARK: - Follow List

struct FollowListUser: Decodable, Identifiable, Equatable {
    let id: String
    let fullName: String
    let username: String?
    let avatarUrl: String?
    var isFollowing: Bool
}

struct FollowListResponse: Decodable {
    let users: [FollowListUser]
    let nextCursor: String?
    let hasMore: Bool
}

enum FollowListTab: String, CaseIterable {
    case followers = "Followers"
    case following = "Following"
}

// MARK: - Simple Success

struct SuccessResponse: Decodable {
    let success: Bool
}
