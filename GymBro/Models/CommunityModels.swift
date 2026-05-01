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
    let reactions: [PostReaction]?
    let reactionCount: Int?
    let isFollowingAuthor: Bool
    let isOwnPost: Bool
    let createdAt: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
        lhs.likeCount == rhs.likeCount &&
        lhs.commentCount == rhs.commentCount &&
        lhs.isLiked == rhs.isLiked &&
        lhs.reactions == rhs.reactions &&
        lhs.isFollowingAuthor == rhs.isFollowingAuthor
    }

    func withReactions(_ newReactions: [PostReaction], reactionCount newCount: Int) -> CommunityPost {
        CommunityPost(
            id: id, user: user, content: content, visibility: visibility,
            photoUrl: photoUrl, workoutAttachment: workoutAttachment,
            likeCount: newCount, commentCount: commentCount, isLiked: isLiked,
            reactions: newReactions, reactionCount: newCount,
            isFollowingAuthor: isFollowingAuthor, isOwnPost: isOwnPost, createdAt: createdAt
        )
    }

    func withCommentCount(_ count: Int) -> CommunityPost {
        CommunityPost(
            id: id, user: user, content: content, visibility: visibility,
            photoUrl: photoUrl, workoutAttachment: workoutAttachment,
            likeCount: likeCount, commentCount: count, isLiked: isLiked,
            reactions: reactions, reactionCount: reactionCount,
            isFollowingAuthor: isFollowingAuthor, isOwnPost: isOwnPost, createdAt: createdAt
        )
    }

    func withFollowing(_ following: Bool) -> CommunityPost {
        CommunityPost(
            id: id, user: user, content: content, visibility: visibility,
            photoUrl: photoUrl, workoutAttachment: workoutAttachment,
            likeCount: likeCount, commentCount: commentCount, isLiked: isLiked,
            reactions: reactions, reactionCount: reactionCount,
            isFollowingAuthor: following, isOwnPost: isOwnPost, createdAt: createdAt
        )
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

// MARK: - Reactions

struct PostReaction: Decodable, Equatable, Identifiable {
    let emoji: String
    let count: Int
    let isReacted: Bool
    var id: String { emoji }
}

enum ReactionEmoji: String, CaseIterable {
    case fire, muscle, clap, wow, trophy

    var display: String {
        switch self {
        case .fire: return "\u{1F525}"
        case .muscle: return "\u{1F4AA}"
        case .clap: return "\u{1F44F}"
        case .wow: return "\u{1F62E}"
        case .trophy: return "\u{1F3C6}"
        }
    }
}

struct ReactionResponse: Decodable {
    let reactions: [PostReaction]
    let totalReactionCount: Int
}

// MARK: - Like Response (legacy)

struct LikeResponse: Decodable {
    let isLiked: Bool
    let likeCount: Int
}

// MARK: - User Search

struct SearchUserResult: Decodable, Identifiable, Equatable {
    let id: String
    let fullName: String
    let username: String?
    let avatarUrl: String?
    var isFollowing: Bool
}

struct SearchUsersResponse: Decodable {
    let users: [SearchUserResult]
}

// MARK: - Suggested Users

struct SuggestedUser: Decodable, Identifiable, Equatable {
    let id: String
    let fullName: String
    let username: String?
    let avatarUrl: String?
    let sessionCount: Int
}

struct SuggestedUsersResponse: Decodable {
    let users: [SuggestedUser]
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

// MARK: - Report & Block

enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case inappropriateContent = "inappropriate_content"
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment"
        case .inappropriateContent: return "Inappropriate Content"
        case .other: return "Other"
        }
    }
}

struct ReportResponse: Decodable {
    let success: Bool
}

struct BlockedUser: Decodable, Identifiable {
    let id: String
    let fullName: String
    let username: String?
    let avatarUrl: String?
    let blockedAt: String
}

struct BlockedUsersResponse: Decodable {
    let users: [BlockedUser]
}

// MARK: - Simple Success

struct SuccessResponse: Decodable {
    let success: Bool
}
