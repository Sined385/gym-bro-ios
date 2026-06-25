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
    let shareConfig: ShareConfig?
    let cardImageUrl: String?
    let workoutAttachment: WorkoutAttachment?
    let commentCount: Int
    let reactions: [PostReaction]?
    let reactionCount: Int?
    let isFollowingAuthor: Bool
    let isOwnPost: Bool
    let createdAt: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
        lhs.commentCount == rhs.commentCount &&
        lhs.reactions == rhs.reactions &&
        lhs.isFollowingAuthor == rhs.isFollowingAuthor
    }

    init(
        id: String, user: PostUser, content: String, visibility: String,
        photoUrl: String?, shareConfig: ShareConfig? = nil, cardImageUrl: String? = nil,
        workoutAttachment: WorkoutAttachment?,
        commentCount: Int,
        reactions: [PostReaction]?, reactionCount: Int?,
        isFollowingAuthor: Bool, isOwnPost: Bool, createdAt: String
    ) {
        self.id = id; self.user = user; self.content = content; self.visibility = visibility
        self.photoUrl = photoUrl; self.shareConfig = shareConfig; self.cardImageUrl = cardImageUrl
        self.workoutAttachment = workoutAttachment
        self.commentCount = commentCount
        self.reactions = reactions; self.reactionCount = reactionCount
        self.isFollowingAuthor = isFollowingAuthor; self.isOwnPost = isOwnPost; self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, user, content, visibility, photoUrl, shareConfig, cardImageUrl
        case workoutAttachment, commentCount, reactions, reactionCount
        case isFollowingAuthor, isOwnPost, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.user = try c.decode(PostUser.self, forKey: .user)
        self.content = try c.decode(String.self, forKey: .content)
        self.visibility = try c.decode(String.self, forKey: .visibility)
        self.photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        self.shareConfig = try c.decodeIfPresent(ShareConfig.self, forKey: .shareConfig)
        self.cardImageUrl = try c.decodeIfPresent(String.self, forKey: .cardImageUrl)
        self.workoutAttachment = try c.decodeIfPresent(WorkoutAttachment.self, forKey: .workoutAttachment)
        self.commentCount = try c.decode(Int.self, forKey: .commentCount)
        self.reactions = try c.decodeIfPresent([PostReaction].self, forKey: .reactions)
        self.reactionCount = try c.decodeIfPresent(Int.self, forKey: .reactionCount)
        self.isFollowingAuthor = try c.decode(Bool.self, forKey: .isFollowingAuthor)
        self.isOwnPost = try c.decode(Bool.self, forKey: .isOwnPost)
        self.createdAt = try c.decode(String.self, forKey: .createdAt)
    }

    func withReactions(_ newReactions: [PostReaction], reactionCount newCount: Int) -> CommunityPost {
        CommunityPost(
            id: id, user: user, content: content, visibility: visibility,
            photoUrl: photoUrl, shareConfig: shareConfig, cardImageUrl: cardImageUrl,
            workoutAttachment: workoutAttachment,
            commentCount: commentCount,
            reactions: newReactions, reactionCount: newCount,
            isFollowingAuthor: isFollowingAuthor, isOwnPost: isOwnPost, createdAt: createdAt
        )
    }

    func withCommentCount(_ count: Int) -> CommunityPost {
        CommunityPost(
            id: id, user: user, content: content, visibility: visibility,
            photoUrl: photoUrl, shareConfig: shareConfig, cardImageUrl: cardImageUrl,
            workoutAttachment: workoutAttachment,
            commentCount: count,
            reactions: reactions, reactionCount: reactionCount,
            isFollowingAuthor: isFollowingAuthor, isOwnPost: isOwnPost, createdAt: createdAt
        )
    }

    func withFollowing(_ following: Bool) -> CommunityPost {
        CommunityPost(
            id: id, user: user, content: content, visibility: visibility,
            photoUrl: photoUrl, shareConfig: shareConfig, cardImageUrl: cardImageUrl,
            workoutAttachment: workoutAttachment,
            commentCount: commentCount,
            reactions: reactions, reactionCount: reactionCount,
            isFollowingAuthor: isFollowingAuthor, isOwnPost: isOwnPost, createdAt: createdAt
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
    let calories: Int?
    let avgHeartRate: Int?
    let exerciseCount: Int
    let aiGenerated: Bool?
    let rpe: Int?
    let exercises: [AttachmentExercise]?

    private enum CodingKeys: String, CodingKey {
        case sessionId, title, durationMinutes, calories, avgHeartRate
        case exerciseCount, aiGenerated, rpe, exercises
    }

    // Tolerant decoder — older payloads (and any path that doesn't surface
    // calories yet) decode without throwing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.title = try c.decode(String.self, forKey: .title)
        self.durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        self.calories = try c.decodeIfPresent(Int.self, forKey: .calories)
        self.avgHeartRate = try c.decodeIfPresent(Int.self, forKey: .avgHeartRate)
        self.exerciseCount = (try? c.decode(Int.self, forKey: .exerciseCount)) ?? 0
        self.aiGenerated = try c.decodeIfPresent(Bool.self, forKey: .aiGenerated)
        self.rpe = try c.decodeIfPresent(Int.self, forKey: .rpe)
        self.exercises = try c.decodeIfPresent([AttachmentExercise].self, forKey: .exercises)
    }
}

struct AttachmentSetData: Decodable, Equatable, Identifiable {
    let setNumber: Int
    let weight: Double?
    let weightUnit: String?
    let reps: Int
    let isBodyweight: Bool
    // Cardio fields — logged time / distance. Nil for strength.
    let durationSeconds: Int?
    let distanceMeters: Int?

    private enum CodingKeys: String, CodingKey {
        case setNumber, weight, weightUnit, reps, isBodyweight
        case durationSeconds, distanceMeters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.setNumber = try c.decode(Int.self, forKey: .setNumber)
        self.weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        self.weightUnit = try c.decodeIfPresent(String.self, forKey: .weightUnit)
        self.reps = try c.decode(Int.self, forKey: .reps)
        self.isBodyweight = try c.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
        self.durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
        self.distanceMeters = try c.decodeIfPresent(Int.self, forKey: .distanceMeters)
    }

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
    case heart, fire, muscle, clap, wow, trophy

    var display: String {
        switch self {
        case .heart: return "\u{2764}\u{FE0F}"
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
    let primaryGoal: String?
    let primaryGoals: [String]?
    let experienceLevel: String?
    let bodyWeightKg: Double?
    let memberSince: String?
    let consistencyStats: ConsistencyStats
    let extendedStats: ExtendedStats?
    let profileStats: ProfileStats?
    let followerCount: Int?
    let followingCount: Int?
    let isFollowing: Bool
    let followsMe: Bool
    let recentPosts: [CommunityPost]
    let isOwnProfile: Bool
}

/// Grouped stats that lead the redesigned Overview tab.
struct ProfileStats: Decodable {
    let oneRepMax: OneRepMax?
    let bodyWeightKg: Double?
    let weekStreak: Int?
    let avgSessionsPerWeek: Double?
    let topMuscleGroups: [String]?
}

/// Estimated 1-rep maxes (kg). Nil for a lift the user has never logged.
struct OneRepMax: Decodable {
    let bench: Int?
    let squat: Int?
    let deadlift: Int?
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
    let primaryGoal: String?
    let primaryGoals: [String]?
    let experienceLevel: String?
    let bodyWeightKg: Double?
    let memberSince: String
    let consistencyStats: ConsistencyStats
    let extendedStats: ExtendedStats
    let profileStats: ProfileStats?
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

// MARK: - Profile Posts (grid)

struct ProfilePostsResponse: Decodable {
    let posts: [CommunityPost]
    let nextCursor: String?
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
    let avgHeartRate: Int?
    let completedAt: String
    let exercises: [HistoryExercise]

    private enum CodingKeys: String, CodingKey {
        case id, title, type, durationMinutes, calories, avgHeartRate, completedAt, exercises
    }

    // Tolerant decoder so older API payloads (pre avg_heart_rate column)
    // still decode without dropping the whole workout.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.type = try c.decode(String.self, forKey: .type)
        self.durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        self.calories = try c.decodeIfPresent(Int.self, forKey: .calories)
        self.avgHeartRate = try c.decodeIfPresent(Int.self, forKey: .avgHeartRate)
        self.completedAt = try c.decode(String.self, forKey: .completedAt)
        self.exercises = (try? c.decode([HistoryExercise].self, forKey: .exercises)) ?? []
    }
}

// MARK: - Head-to-head comparison

/// Deterministic head-to-head between the viewer and the profile owner. The
/// server picks whatever metrics the two users have in common (shared lifts by
/// estimated 1RM, plus shared activity stats) — `metrics` is dynamic.
struct HeadToHead: Decodable {
    // currentUser/otherUser/metrics are absent when `locked` (free tier) — the
    // server skips generation and returns only `{ locked: true }`.
    let currentUser: ComparisonParticipant?
    let otherUser: ComparisonParticipant?
    let metrics: [ComparisonMetric]?
    let analysis: ComparisonAnalysis?
    let locked: Bool?
}

struct ComparisonParticipant: Decodable {
    let userId: String
    let fullName: String
}

/// AI-written read of the head-to-head, generated from the dynamic metrics.
struct ComparisonAnalysis: Decodable {
    let verdict: String
    let yourEdge: String?
    let theirEdge: String?
    let takeaway: String?
}

struct ComparisonMetric: Decodable, Identifiable {
    let key: String
    let label: String
    let unit: String?
    let currentValue: Double
    let otherValue: Double
    let higherIsBetter: Bool?
    var id: String { key }
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
