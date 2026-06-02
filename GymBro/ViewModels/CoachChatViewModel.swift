//
//  CoachChatViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import Foundation
import Combine
import SwiftUI
import Supabase

// MARK: - Response Models

struct CoachMessageResponse: Identifiable {
    let id: String
    let role: String
    var content: String
    var session: CoachSessionCard?
    let createdAt: Date

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
}

struct CoachSessionCard: Decodable {
    let id: String
    let title: String
    let type: String
    let durationMinutes: Int?
    let exercises: [DashboardExercise]
}

struct ConversationSummary: Decodable, Identifiable {
    let id: String
    let lastMessage: String?
    let createdAt: String
}

struct ConversationsListResponse: Decodable {
    let conversations: [ConversationSummary]
}

struct GetConversationResponse: Decodable {
    let conversationId: String
}

struct ConversationMessagesResponse: Decodable {
    let conversationId: String
    let hasMore: Bool
    let messages: [APICoachMessage]
}

struct APICoachMessage: Decodable {
    let id: String
    let role: String
    let content: String
    let createdAt: String
    let session: CoachSessionCard?
}

// MARK: - SSE Event Types

private struct SSETextDelta: Decodable {
    let content: String
}

private struct SSESessionCreated: Decodable {
    let session: CoachSessionCard
}

private struct SSEDone: Decodable {
    let messageId: String
    let conversationId: String
}

// MARK: - ViewModel

@MainActor
final class CoachChatViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var messages: [CoachMessageResponse] = []
    @Published var inputText: String = ""
    @Published var isStreaming: Bool = false
    @Published var isLoadingHistory: Bool = false
    @Published var hasMoreMessages: Bool = false
    @Published var conversationId: String?
    @Published var errorMessage: String?
    @Published var isLimitReached: Bool = false

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let sessionManager: ActiveSessionManager
    private let appDataState: AppDataState
    private let analyticsService: AnalyticsTrackingServiceProtocol
    let subscriptionManager: SubscriptionManager

    // MARK: - Quick Actions

    let quickActions = [
        "Build my plan",
        "Create today's workout",
        "Swap an exercise",
        "Make it shorter",
        "I only have dumbbells"
    ]

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, sessionManager: ActiveSessionManager, appDataState: AppDataState, analyticsService: AnalyticsTrackingServiceProtocol, subscriptionManager: SubscriptionManager) {
        self.networkService = networkService
        self.sessionManager = sessionManager
        self.appDataState = appDataState
        self.analyticsService = analyticsService
        self.subscriptionManager = subscriptionManager

        // When premium activates, clear limit blocker
        subscriptionManager.$isPremium
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.isLimitReached = false
            }
            .store(in: &cancellables)
    }

    // MARK: - Load History

    func loadConversation() async {
        guard conversationId == nil else { return }

        // Check coach access upfront
        await subscriptionManager.loadStatus()
        if !subscriptionManager.isPremium && subscriptionManager.coachMessagesUsed >= subscriptionManager.coachMessagesLimit {
            isLimitReached = true
        }

        do {
            let convResponse = try await networkService.request(
                CoachRouter.getConversation.endpoint,
                responseType: GetConversationResponse.self
            )
            conversationId = convResponse.conversationId

            let messagesResponse = try await networkService.request(
                CoachRouter.getMessages(conversationId: convResponse.conversationId, limit: 50, before: nil).endpoint,
                responseType: ConversationMessagesResponse.self
            )

            hasMoreMessages = messagesResponse.hasMore
            messages = messagesResponse.messages.map { apiMsg in
                CoachMessageResponse(
                    id: apiMsg.id,
                    role: apiMsg.role,
                    content: apiMsg.content,
                    session: apiMsg.session,
                    createdAt: ISO8601DateFormatter().date(from: apiMsg.createdAt) ?? Date()
                )
            }
        } catch {
            // No conversation yet — show welcome screen
        }
    }


    func loadMoreMessages() async {
        guard let convId = conversationId, hasMoreMessages, !isLoadingHistory else { return }
        guard let oldestId = messages.first?.id else { return }

        isLoadingHistory = true

        do {
            let response = try await networkService.request(
                CoachRouter.getMessages(conversationId: convId, limit: 50, before: oldestId).endpoint,
                responseType: ConversationMessagesResponse.self
            )

            hasMoreMessages = response.hasMore
            let older = response.messages.map { apiMsg in
                CoachMessageResponse(
                    id: apiMsg.id,
                    role: apiMsg.role,
                    content: apiMsg.content,
                    session: apiMsg.session,
                    createdAt: ISO8601DateFormatter().date(from: apiMsg.createdAt) ?? Date()
                )
            }
            messages.insert(contentsOf: older, at: 0)
        } catch {
            // Silently fail — user can retry by scrolling up again
        }

        isLoadingHistory = false
    }

    // MARK: - Actions

    func sendMessage(_ text: String? = nil) async {
        let content = text ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        // Block if limit reached
        if isLimitReached {
            subscriptionManager.showPaywall = true
            return
        }

        inputText = ""
        errorMessage = nil

        // Add optimistic user bubble
        let userMessage = CoachMessageResponse(
            id: UUID().uuidString,
            role: "user",
            content: content,
            session: nil,
            createdAt: Date()
        )
        messages.append(userMessage)

        // Add placeholder assistant bubble
        let assistantId = UUID().uuidString
        let assistantMessage = CoachMessageResponse(
            id: assistantId,
            role: "assistant",
            content: "",
            session: nil,
            createdAt: Date()
        )
        messages.append(assistantMessage)

        isStreaming = true

        await streamChat(content: content)

        isStreaming = false

        // Auto-recover if stream was interrupted (e.g. app backgrounded)
        if !streamCompleted, conversationId != nil {
            await reloadMessages()
        }
    }

    func handleQuickAction(_ action: String) async {
        analyticsService.track("coach_quick_action", properties: ["action": action])
        await sendMessage(action)
    }

    func startWorkout(from message: CoachMessageResponse) async {
        guard let session = message.session else { return }

        sessionManager.requestSessionStart { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.networkService.request(
                    CoachRouter.startSessionFromChat(sessionId: session.id).endpoint,
                    responseType: SessionResponse.self
                )
                self.sessionManager.openSession(response)
                self.analyticsService.track("coach_workout_started", properties: ["session_id": session.id])
            } catch {
                let mockResponse = SessionResponse(
                    id: session.id,
                    title: session.title,
                    type: session.type,
                    status: "active",
                    startedAt: ISO8601DateFormatter().string(from: Date()),
                    completedAt: nil,
                    durationMinutes: session.durationMinutes,
                    calories: nil,
                    aiGenerated: true,
                    aiMessage: nil,
                    exercises: session.exercises
                )
                self.sessionManager.openSession(mockResponse)
            }
        }
    }

    func regenerateWorkout(messageId: String) async {
        // The system prompt's PROGRESSIVE OVERLOAD directive tells the AI to
        // reuse recent lifts with target_sets — which is right for fresh
        // requests but loops on "regenerate" because a plain "give me a
        // different option" loses to the stronger reuse rule. Pass the
        // prior session's exercise names as an explicit skip list so the
        // AI picks different lifts this time.
        let prior = messages.first(where: { $0.id == messageId })?.session
        let names = prior?.exercises.map(\.name) ?? []
        let avoid = names.joined(separator: ", ")
        let prompt = avoid.isEmpty
            ? "Regenerate the workout — give me a different option"
            : "Regenerate the workout. Skip these — pick different exercises: \(avoid)."
        await sendMessage(prompt)
    }

    // MARK: - Background Recovery

    private var streamCompleted = false

    func recoverFromBackground() async {
        guard !streamCompleted, !isStreaming else { return }
        await reloadMessages()
    }

    private func reloadMessages() async {
        guard let convId = conversationId else { return }

        do {
            let response = try await networkService.request(
                CoachRouter.getMessages(conversationId: convId, limit: 50, before: nil).endpoint,
                responseType: ConversationMessagesResponse.self
            )
            hasMoreMessages = response.hasMore
            messages = response.messages.map { apiMsg in
                CoachMessageResponse(
                    id: apiMsg.id,
                    role: apiMsg.role,
                    content: apiMsg.content,
                    session: apiMsg.session,
                    createdAt: ISO8601DateFormatter().date(from: apiMsg.createdAt) ?? Date()
                )
            }
        } catch {
            // Keep whatever partial content we have
        }
    }

    // MARK: - SSE Streaming

    private func streamChat(content: String) async {
        guard let url = URL(string: "\(baseURL)/api/v1/coach/chat") else { return }

        streamCompleted = false

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // Add auth token
        if let token = try? await SupabaseConfig.client.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Build body
        var body: [String: Any] = ["content": content]
        if let convId = conversationId {
            body["conversation_id"] = convId
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                updateLastAssistantMessage(content: "Sorry, something went wrong. Please try again.")
                return
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            var currentEvent = ""

            for try await line in bytes.lines {
                if line.hasPrefix("event: ") {
                    currentEvent = String(line.dropFirst(7))
                } else if line.hasPrefix("data: ") {
                    let dataString = String(line.dropFirst(6))
                    guard let data = dataString.data(using: .utf8) else { continue }

                    switch currentEvent {
                    case "text_delta":
                        if let delta = try? decoder.decode(SSETextDelta.self, from: data) {
                            appendToLastAssistantMessage(delta.content)
                        }

                    case "session_created":
                        if let sessionEvent = try? decoder.decode(SSESessionCreated.self, from: data) {
                            setSessionOnLastAssistantMessage(sessionEvent.session)
                            // Phase 3: ask AppContext to re-hydrate so
                            // Home + Plan tabs see the new session
                            // without each issuing their own fetch.
                            Task { [appDataState] in
                                await appDataState.refresh(reason: .coachAction)
                            }
                            analyticsService.track("coach_tool_used", properties: ["tool_type": "session_created"])
                        }

                    case "plan_modified", "plan_generated":
                        Task { [appDataState] in
                            await appDataState.refresh(reason: .coachAction)
                        }
                        analyticsService.track("coach_tool_used", properties: ["tool_type": currentEvent])

                    case "done":
                        if let done = try? decoder.decode(SSEDone.self, from: data) {
                            streamCompleted = true
                            conversationId = done.conversationId
                            // Update the assistant message ID to the real one
                            if var lastMsg = messages.last, lastMsg.isAssistant {
                                messages[messages.count - 1] = CoachMessageResponse(
                                    id: done.messageId,
                                    role: lastMsg.role,
                                    content: lastMsg.content,
                                    session: lastMsg.session,
                                    createdAt: lastMsg.createdAt
                                )
                            }
                        }

                    case "error":
                        // Check if it's a coach limit error
                        if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let code = errorData["code"] as? String,
                           code == "COACH_LIMIT_REACHED" {
                            isLimitReached = true
                            updateLastAssistantMessage(content: "You've used all 20 free messages. Upgrade to Premium for unlimited AI coaching.")
                        } else {
                            updateLastAssistantMessage(content: "Sorry, something went wrong. Please try again.")
                        }

                    default:
                        break
                    }
                }
            }
        } catch {
            // Connection dropped (e.g. app backgrounded) — don't overwrite partial content
            if !streamCompleted {
                // Only show error if we have no content at all
                if let lastMsg = messages.last, lastMsg.isAssistant, lastMsg.content.isEmpty {
                    updateLastAssistantMessage(content: "Connection lost. Recovering…")
                }
            }
        }
    }

    // MARK: - Message Helpers

    private func appendToLastAssistantMessage(_ text: String) {
        guard messages.count > 0 else { return }
        let lastIndex = messages.count - 1
        if messages[lastIndex].isAssistant {
            messages[lastIndex].content += text
        }
    }

    private func setSessionOnLastAssistantMessage(_ session: CoachSessionCard) {
        guard messages.count > 0 else { return }
        let lastIndex = messages.count - 1
        if messages[lastIndex].isAssistant {
            messages[lastIndex].session = session
        }
    }

    private func updateLastAssistantMessage(content: String) {
        guard messages.count > 0 else { return }
        let lastIndex = messages.count - 1
        if messages[lastIndex].isAssistant {
            messages[lastIndex].content = content
        }
    }

    private var baseURL: String {
        AppEnvironment.current.apiBaseURL
    }
}
