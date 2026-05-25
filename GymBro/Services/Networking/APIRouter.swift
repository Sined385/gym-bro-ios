//
//  APIRouter.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import Foundation

// MARK: - Router Protocol

protocol APIRouter {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: [String: Any]? { get }
    var encoding: ParameterEncoding { get }
}

extension APIRouter {
    var endpoint: APIEndpoint {
        APIEndpoint(
            path: path,
            method: method,
            parameters: parameters,
            encoding: encoding
        )
    }
}

// MARK: - Auth Router

enum AuthRouter: APIRouter {
    case onboardingStatus

    var path: String {
        switch self {
        case .onboardingStatus:
            return "/api/v1/onboarding/status"
        }
    }

    var method: HTTPMethod { .get }
    var parameters: [String: Any]? { nil }
    var encoding: ParameterEncoding { .url }
}

// MARK: - Onboarding Router

enum OnboardingRouter: APIRouter {
    case submit(body: [String: Any])
    case fetch
    case updateRestTime(seconds: Int)

    var path: String { "/api/v1/onboarding" }

    var method: HTTPMethod {
        switch self {
        case .submit: return .put
        case .fetch: return .get
        case .updateRestTime: return .patch
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .submit(let body): return body
        case .fetch: return nil
        case .updateRestTime(let seconds): return ["preferred_rest_time": seconds]
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .fetch: return .url
        default: return .json
        }
    }
}

// MARK: - Home Router

enum HomeRouter: APIRouter {
    case dashboard
    case createSession(title: String, type: String)
    case startSession(sessionId: String)
    case completeSession(sessionId: String)
    case history(date: String)
    case completedDays(month: String)

    var path: String {
        switch self {
        case .dashboard:
            return "/api/v1/home/dashboard"
        case .createSession:
            return "/api/v1/home/sessions"
        case .startSession(let sessionId):
            return "/api/v1/home/sessions/\(sessionId)/start"
        case .completeSession(let sessionId):
            return "/api/v1/home/sessions/\(sessionId)/complete"
        case .history:
            return "/api/v1/home/history"
        case .completedDays:
            return "/api/v1/home/completed-days"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .dashboard, .history, .completedDays: return .get
        case .createSession, .startSession: return .post
        case .completeSession: return .patch
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .dashboard:
            return nil
        case .createSession(let title, let type):
            return ["title": title, "type": type]
        case .startSession:
            return nil
        case .completeSession:
            return nil
        case .history(let date):
            return ["date": date]
        case .completedDays(let month):
            return ["month": month]
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .createSession: return .json
        case .completeSession: return .json
        default: return .url
        }
    }
}

// MARK: - Exercise Library Router

enum ExerciseRouter: APIRouter {
    case list
    case create(name: String, muscleGroup: String, equipment: String)
    case detail(exerciseId: String)
    case previousSets(exerciseId: String)
    case favorite(exerciseId: String)
    case unfavorite(exerciseId: String)

    var path: String {
        switch self {
        case .list, .create:
            return "/api/v1/exercises"
        case .detail(let exerciseId):
            return "/api/v1/exercises/\(exerciseId)"
        case .previousSets(let exerciseId):
            return "/api/v1/exercises/\(exerciseId)/previous-sets"
        case .favorite(let exerciseId), .unfavorite(let exerciseId):
            return "/api/v1/exercises/\(exerciseId)/favorite"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail, .previousSets: return .get
        case .create, .favorite: return .post
        case .unfavorite: return .delete
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .list, .detail, .previousSets, .favorite, .unfavorite:
            return nil
        case .create(let name, let muscleGroup, let equipment):
            return [
                "name": name,
                "muscle_group": muscleGroup,
                "equipment": equipment
            ]
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .create: return .json
        default: return .url
        }
    }
}

// MARK: - Session Flow Router

enum SessionRouter: APIRouter {
    case addExercises(sessionId: String, exercises: [[String: Any]])
    case createSuperset(sessionId: String, exerciseIds: [String])
    case reorderExercises(sessionId: String, exerciseIds: [String])
    case removeExercise(sessionId: String, exerciseId: String)
    case logSet(sessionId: String, exerciseId: String, setNumber: Int, weight: Any, weightUnit: String, reps: Int)
    case updateSet(sessionId: String, exerciseId: String, setId: String, params: [String: Any])
    case deleteSet(sessionId: String, exerciseId: String, setId: String)
    case completeWithFeedback(sessionId: String, feedback: [String: Any], durationMinutes: Int)
    case completeSessionFull(sessionId: String, payload: [String: Any])

    var path: String {
        switch self {
        case .addExercises(let sessionId, _):
            return "/api/v1/home/sessions/\(sessionId)/exercises"
        case .createSuperset(let sessionId, _):
            return "/api/v1/home/sessions/\(sessionId)/supersets"
        case .reorderExercises(let sessionId, _):
            return "/api/v1/home/sessions/\(sessionId)/exercises/reorder"
        case .removeExercise(let sessionId, let exerciseId):
            return "/api/v1/home/sessions/\(sessionId)/exercises/\(exerciseId)"
        case .logSet(let sessionId, let exerciseId, _, _, _, _):
            return "/api/v1/home/sessions/\(sessionId)/exercises/\(exerciseId)/sets"
        case .updateSet(let sessionId, let exerciseId, let setId, _):
            return "/api/v1/home/sessions/\(sessionId)/exercises/\(exerciseId)/sets/\(setId)"
        case .deleteSet(let sessionId, let exerciseId, let setId):
            return "/api/v1/home/sessions/\(sessionId)/exercises/\(exerciseId)/sets/\(setId)"
        case .completeWithFeedback(let sessionId, _, _):
            return "/api/v1/home/sessions/\(sessionId)/complete"
        case .completeSessionFull(let sessionId, _):
            return "/api/v1/home/sessions/\(sessionId)/complete-full"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .addExercises, .createSuperset, .logSet, .completeSessionFull: return .post
        case .updateSet, .completeWithFeedback, .reorderExercises: return .patch
        case .removeExercise, .deleteSet: return .delete
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .addExercises(_, let exercises):
            return ["exercises": exercises]
        case .createSuperset(_, let exerciseIds):
            return ["exercise_ids": exerciseIds]
        case .reorderExercises(_, let exerciseIds):
            return ["exercise_ids": exerciseIds]
        case .removeExercise, .deleteSet:
            return nil
        case .logSet(_, _, let setNumber, let weight, let weightUnit, let reps):
            return [
                "set_number": setNumber,
                "weight": weight,
                "weight_unit": weightUnit,
                "reps": reps
            ]
        case .updateSet(_, _, _, let params):
            return params
        case .completeWithFeedback(_, let feedback, let durationMinutes):
            return ["feedback": feedback, "duration_minutes": durationMinutes]
        case .completeSessionFull(_, let payload):
            return payload
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .removeExercise, .deleteSet: return .url
        default: return .json
        }
    }
}

// MARK: - Coach Router

enum CoachRouter: APIRouter {
    case sendMessage(content: String, conversationId: String?)
    case listConversations
    case getConversation
    case getMessages(conversationId: String, limit: Int, before: String?)
    case startSessionFromChat(sessionId: String)
    case messageAction(messageId: String, action: String)

    var path: String {
        switch self {
        case .sendMessage:
            return "/api/v1/coach/chat"
        case .listConversations:
            return "/api/v1/coach/conversations"
        case .getConversation:
            return "/api/v1/coach/conversations/current"
        case .getMessages(let conversationId, _, _):
            return "/api/v1/coach/conversations/\(conversationId)/messages"
        case .startSessionFromChat(let sessionId):
            return "/api/v1/home/sessions/\(sessionId)/start"
        case .messageAction(let messageId, _):
            return "/api/v1/coach/chat/\(messageId)/action"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listConversations, .getConversation, .getMessages: return .get
        case .sendMessage, .startSessionFromChat, .messageAction: return .post
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .sendMessage(let content, let conversationId):
            var params: [String: Any] = ["content": content]
            if let convId = conversationId { params["conversation_id"] = convId }
            return params
        case .listConversations, .startSessionFromChat, .getConversation:
            return nil
        case .getMessages(_, let limit, let before):
            var params: [String: Any] = ["limit": limit]
            if let b = before { params["before"] = b }
            return params
        case .messageAction(_, let action):
            return ["action": action]
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .listConversations, .getConversation, .getMessages: return .url
        default: return .json
        }
    }
}

// MARK: - Workout Router

enum WorkoutRouter: APIRouter {
    case sync(workoutId: String, activityType: UInt, startDate: String, endDate: String, duration: Double, totalEnergyBurned: Double?, totalDistance: Double?)

    var path: String { "/api/workouts" }
    var method: HTTPMethod { .post }

    var parameters: [String: Any]? {
        switch self {
        case .sync(let workoutId, let activityType, let startDate, let endDate, let duration, let totalEnergyBurned, let totalDistance):
            var params: [String: Any] = [
                "workout_id": workoutId,
                "activity_type": activityType,
                "start_date": startDate,
                "end_date": endDate,
                "duration": duration
            ]
            if let energy = totalEnergyBurned { params["total_energy_burned"] = energy }
            if let distance = totalDistance { params["total_distance"] = distance }
            return params
        }
    }

    var encoding: ParameterEncoding { .json }
}

// MARK: - Community Router

enum CommunityRouter: APIRouter {
    case feed(tab: String, cursor: String?, limit: Int)
    case getPost(postId: String)
    case createPost(content: String, visibility: String, workoutSessionId: String?, photoUrl: String?, shareConfig: [String: Any]?, cardImageUrl: String?)
    case deletePost(postId: String)
    case toggleLike(postId: String)
    case toggleReaction(postId: String, emoji: String)
    case getComments(postId: String, cursor: String?, limit: Int)
    case createComment(postId: String, content: String)
    case deleteComment(commentId: String)
    case followUser(userId: String)
    case unfollowUser(userId: String)
    case myProfile
    case myWorkouts(cursor: String?, limit: Int)
    case searchUsers(query: String, limit: Int)
    case suggestedUsers(limit: Int)
    case userProfile(userId: String)
    case userWorkouts(userId: String, cursor: String?, limit: Int)
    case userCompare(userId: String)
    case myFollowers(cursor: String?, limit: Int)
    case myFollowing(cursor: String?, limit: Int)
    case reportContent(contentType: String, contentId: String, reason: String, description: String?)
    case blockUser(userId: String)
    case unblockUser(userId: String)
    case blockedUsers

    var path: String {
        switch self {
        case .feed:
            return "/api/v1/community/feed"
        case .getPost(let postId):
            return "/api/v1/community/posts/\(postId)"
        case .createPost:
            return "/api/v1/community/posts"
        case .deletePost(let postId):
            return "/api/v1/community/posts/\(postId)"
        case .toggleLike(let postId):
            return "/api/v1/community/posts/\(postId)/like"
        case .toggleReaction(let postId, _):
            return "/api/v1/community/posts/\(postId)/react"
        case .getComments(let postId, _, _):
            return "/api/v1/community/posts/\(postId)/comments"
        case .createComment(let postId, _):
            return "/api/v1/community/posts/\(postId)/comments"
        case .deleteComment(let commentId):
            return "/api/v1/community/comments/\(commentId)"
        case .followUser:
            return "/api/v1/community/follow"
        case .unfollowUser(let userId):
            return "/api/v1/community/follow/\(userId)"
        case .myProfile:
            return "/api/v1/community/me/profile"
        case .myWorkouts:
            return "/api/v1/community/me/workouts"
        case .searchUsers:
            return "/api/v1/community/users/search"
        case .suggestedUsers:
            return "/api/v1/community/users/suggested"
        case .userProfile(let userId):
            return "/api/v1/community/users/\(userId)/profile"
        case .userWorkouts(let userId, _, _):
            return "/api/v1/community/users/\(userId)/workouts"
        case .userCompare(let userId):
            return "/api/v1/community/users/\(userId)/compare"
        case .myFollowers:
            return "/api/v1/community/me/followers"
        case .myFollowing:
            return "/api/v1/community/me/following"
        case .reportContent:
            return "/api/v1/community/reports"
        case .blockUser:
            return "/api/v1/community/blocks"
        case .unblockUser(let userId):
            return "/api/v1/community/blocks/\(userId)"
        case .blockedUsers:
            return "/api/v1/community/blocks"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .feed, .getPost, .getComments, .myProfile, .myWorkouts, .searchUsers, .suggestedUsers,
             .userProfile, .userWorkouts, .userCompare, .myFollowers, .myFollowing, .blockedUsers:
            return .get
        case .createPost, .toggleLike, .toggleReaction, .createComment, .followUser, .reportContent, .blockUser:
            return .post
        case .deletePost, .deleteComment, .unfollowUser, .unblockUser:
            return .delete
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .feed(let tab, let cursor, let limit):
            var params: [String: Any] = ["tab": tab, "limit": limit]
            if let cursor { params["cursor"] = cursor }
            return params
        case .createPost(let content, let visibility, let workoutSessionId, let photoUrl, let shareConfig, let cardImageUrl):
            var params: [String: Any] = ["content": content, "visibility": visibility]
            if let workoutSessionId { params["workout_session_id"] = workoutSessionId }
            if let photoUrl { params["photo_url"] = photoUrl }
            if let shareConfig { params["share_config"] = shareConfig }
            if let cardImageUrl { params["card_image_url"] = cardImageUrl }
            return params
        case .createComment(_, let content):
            return ["content": content]
        case .followUser(let userId):
            return ["userId": userId]
        case .getComments(_, let cursor, let limit):
            var params: [String: Any] = ["limit": limit]
            if let cursor { params["cursor"] = cursor }
            return params
        case .myWorkouts(let cursor, let limit):
            var params: [String: Any] = ["limit": limit]
            if let cursor { params["cursor"] = cursor }
            return params
        case .userWorkouts(_, let cursor, let limit):
            var params: [String: Any] = ["limit": limit]
            if let cursor { params["cursor"] = cursor }
            return params
        case .myFollowers(let cursor, let limit):
            var params: [String: Any] = ["limit": limit]
            if let cursor { params["cursor"] = cursor }
            return params
        case .myFollowing(let cursor, let limit):
            var params: [String: Any] = ["limit": limit]
            if let cursor { params["cursor"] = cursor }
            return params
        case .reportContent(let contentType, let contentId, let reason, let description):
            var params: [String: Any] = ["contentType": contentType, "contentId": contentId, "reason": reason]
            if let description { params["description"] = description }
            return params
        case .blockUser(let userId):
            return ["userId": userId]
        case .toggleReaction(_, let emoji):
            return ["emoji": emoji]
        case .searchUsers(let query, let limit):
            return ["q": query, "limit": limit]
        case .suggestedUsers(let limit):
            return ["limit": limit]
        case .getPost, .deletePost, .toggleLike, .deleteComment, .unfollowUser,
             .myProfile, .userProfile, .userCompare, .unblockUser, .blockedUsers:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .feed, .getPost, .getComments, .myProfile, .myWorkouts, .searchUsers, .suggestedUsers,
             .userProfile, .userWorkouts, .userCompare,
             .deletePost, .deleteComment, .unfollowUser, .myFollowers, .myFollowing, .unblockUser, .blockedUsers:
            return .url
        default:
            return .json
        }
    }
}

// MARK: - Share Router

enum ShareRouter: APIRouter {
    case createSharedCard(cardImageUrl: String, shareConfig: [String: Any]?, workoutSessionId: String?)

    var path: String {
        switch self {
        case .createSharedCard:
            return "/api/v1/share-cards"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .createSharedCard:
            return .post
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .createSharedCard(let cardImageUrl, let shareConfig, let workoutSessionId):
            var params: [String: Any] = ["card_image_url": cardImageUrl]
            if let shareConfig { params["share_config"] = shareConfig }
            if let workoutSessionId { params["workout_session_id"] = workoutSessionId }
            return params
        }
    }

    var encoding: ParameterEncoding {
        return .json
    }
}

struct SharedCardResponse: Decodable {
    let id: String
    let shareUrl: String
}

// MARK: - Notification Router

enum NotificationRouter: APIRouter {
    case registerToken(token: String, platform: String, timezone: String)
    case removeToken(token: String)
    case list(cursor: String?, limit: Int)
    case unreadCount
    case markRead(notificationId: String)
    case markAllRead

    var path: String {
        switch self {
        case .registerToken, .removeToken:
            return "/api/v1/notifications/device-token"
        case .list:
            return "/api/v1/notifications"
        case .unreadCount:
            return "/api/v1/notifications/unread-count"
        case .markRead(let notificationId):
            return "/api/v1/notifications/\(notificationId)/read"
        case .markAllRead:
            return "/api/v1/notifications/read-all"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .registerToken: return .post
        case .removeToken: return .delete
        case .list, .unreadCount: return .get
        case .markRead, .markAllRead: return .patch
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .registerToken(let token, let platform, let timezone):
            return ["token": token, "platform": platform, "timezone": timezone]
        case .removeToken(let token):
            return ["token": token]
        case .list(let cursor, let limit):
            var params: [String: Any] = ["limit": limit]
            if let cursor { params["cursor"] = cursor }
            return params
        case .unreadCount, .markRead, .markAllRead:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .registerToken, .removeToken: return .json
        case .list, .unreadCount: return .url
        case .markRead, .markAllRead: return .json
        }
    }
}

// MARK: - User Router

enum UserRouter: APIRouter {
    case getProfile
    case updateProfile(body: [String: Any])
    case checkUsername(username: String)
    case uploadAvatar(imageData: Data)

    var path: String {
        switch self {
        case .getProfile, .updateProfile:
            return "/api/v1/user/profile"
        case .checkUsername(let username):
            return "/api/v1/user/check-username/\(username)"
        case .uploadAvatar:
            return "/api/v1/user/avatar"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getProfile, .checkUsername: return .get
        case .updateProfile: return .put
        case .uploadAvatar: return .post
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .getProfile, .checkUsername, .uploadAvatar:
            return nil
        case .updateProfile(let body):
            return body
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .getProfile, .checkUsername: return .url
        case .updateProfile: return .json
        case .uploadAvatar: return .json
        }
    }
}

// MARK: - Analytics Router

enum AnalyticsRouter: APIRouter {
    case trackEvent(eventName: String, properties: [String: Any])

    var path: String { "/api/v1/analytics/events" }
    var method: HTTPMethod { .post }

    var parameters: [String: Any]? {
        switch self {
        case .trackEvent(let eventName, let properties):
            return ["event_name": eventName, "properties": properties]
        }
    }

    var encoding: ParameterEncoding { .json }
}

// MARK: - Plan Router

enum PlanRouter: APIRouter {
    case getActivePlan
    case generatePlan(forceRegenerate: Bool)
    case startPlanSession(dayId: String)

    var path: String {
        switch self {
        case .getActivePlan:
            return "/api/v1/plans"
        case .generatePlan:
            return "/api/v1/plans/generate"
        case .startPlanSession(let dayId):
            return "/api/v1/plans/days/\(dayId)/start"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getActivePlan: return .get
        case .generatePlan, .startPlanSession: return .post
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .getActivePlan, .startPlanSession:
            return nil
        case .generatePlan(let forceRegenerate):
            return ["force": forceRegenerate]
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .getActivePlan: return .url
        case .generatePlan, .startPlanSession: return .json
        }
    }
}

// MARK: - Template Router

enum TemplateRouter: APIRouter {
    case list
    case create(name: String, sessionIds: [String])
    case createFromExercises(name: String, exercises: [[String: Any]])
    case rename(templateId: String, name: String)
    case delete(templateId: String)
    case start(templateId: String)
    case share(templateId: String)
    case saveShared(code: String)

    var path: String {
        switch self {
        case .list, .create, .createFromExercises:
            return "/api/v1/home/templates"
        case .rename(let templateId, _):
            return "/api/v1/home/templates/\(templateId)"
        case .delete(let templateId):
            return "/api/v1/home/templates/\(templateId)"
        case .start(let templateId):
            return "/api/v1/home/templates/\(templateId)/start"
        case .share(let templateId):
            return "/api/v1/home/templates/\(templateId)/share"
        case .saveShared(let code):
            return "/api/v1/home/templates/save-shared/\(code)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list: return .get
        case .create, .createFromExercises, .start, .share, .saveShared: return .post
        case .rename: return .patch
        case .delete: return .delete
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .list, .delete, .start, .share, .saveShared:
            return nil
        case .create(let name, let sessionIds):
            return ["name": name, "session_ids": sessionIds]
        case .createFromExercises(let name, let exercises):
            return ["name": name, "exercises": exercises]
        case .rename(_, let name):
            return ["name": name]
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .list, .delete: return .url
        case .create, .createFromExercises, .rename, .start, .share, .saveShared: return .json
        }
    }
}

// MARK: - Subscription Router

enum SubscriptionRouter: APIRouter {
    case getStatus
    case verify(transactionId: String, productId: String)
    case restore(transactionId: String, productId: String)
    case sync(hasActiveEntitlement: Bool, transactionId: String?, productId: String?)

    var path: String {
        switch self {
        case .getStatus:
            return "/api/v1/subscription/status"
        case .verify:
            return "/api/v1/subscription/verify"
        case .restore:
            return "/api/v1/subscription/restore"
        case .sync:
            return "/api/v1/subscription/sync"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getStatus: return .get
        case .verify, .restore, .sync: return .post
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .getStatus:
            return nil
        case .verify(let transactionId, let productId),
             .restore(let transactionId, let productId):
            return ["transaction_id": transactionId, "product_id": productId]
        case .sync(let hasActive, let transactionId, let productId):
            var params: [String: Any] = ["has_active_entitlement": hasActive]
            if let transactionId { params["transaction_id"] = transactionId }
            if let productId { params["product_id"] = productId }
            return params
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .getStatus: return .url
        case .verify, .restore, .sync: return .json
        }
    }
}

// MARK: - Shared Template Router (Public, no auth)

enum SharedRouter: APIRouter {
    case getShared(code: String)

    var path: String {
        switch self {
        case .getShared(let code):
            return "/api/v1/shared/templates/\(code)"
        }
    }

    var method: HTTPMethod { .get }
    var parameters: [String: Any]? { nil }
    var encoding: ParameterEncoding { .url }
}
