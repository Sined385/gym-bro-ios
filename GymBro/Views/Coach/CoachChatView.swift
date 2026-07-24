//
//  CoachChatView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import SwiftUI
import Combine

struct CoachChatView: View {
    @StateObject private var viewModel: CoachChatViewModel = DependencyContainer.shared.resolve(CoachChatViewModel.self)
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @Environment(\.scenePhase) private var scenePhase

    private let bottomAnchorId = "__chat_bottom__"

    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        // Load more button
                        if viewModel.hasMoreMessages {
                            Button {
                                Task { await viewModel.loadMoreMessages() }
                            } label: {
                                if viewModel.isLoadingHistory {
                                    ProgressView()
                                        .frame(height: 32)
                                } else {
                                    Text("Load earlier messages")
                                        .font(.gymBroSmall)
                                        .foregroundColor(.gymBroTextSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        }

                        // Welcome message if no messages
                        if viewModel.messages.isEmpty && !viewModel.isLoadingHistory {
                            welcomeSection
                        }

                        ForEach(viewModel.messages) { message in
                            CoachMessageBubble(
                                message: message,
                                onStartWorkout: {
                                    Task {
                                        await viewModel.startWorkout(from: message)
                                    }
                                },
                                onRegenerate: {
                                    Task {
                                        await viewModel.regenerateWorkout(
                                            messageId: message.id,
                                            sessionId: message.session?.id
                                        )
                                    }
                                }
                            )
                            .id(message.id)
                        }

                        // Streaming indicator
                        if viewModel.isStreaming {
                            if let lastMsg = viewModel.messages.last, lastMsg.isAssistant, lastMsg.content.isEmpty, lastMsg.session == nil {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                            }
                        }

                        // Limit reached upgrade card
                        if viewModel.isLimitReached {
                            PremiumUpgradeCard(
                                description: "You've used all 20 free messages. Upgrade to Premium for unlimited AI coaching.",
                                subscriptionManager: viewModel.subscriptionManager
                            )
                            .id("upgrade-card")
                        }

                        // Stable anchor at the absolute bottom. Scrolling to
                        // a sentinel (instead of the last message bubble) keeps
                        // the scroll target fixed while the bubble grows from
                        // streaming text — otherwise scrollTo(lastId, .bottom)
                        // re-targets every text_delta and the view bounces.
                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorId)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                // Any change to the last message — new append OR streaming
                // delta — instantly pins the view to the bottom anchor.
                // We used to also have a separate `onChange(messages.count)`
                // running an animated scroll; sending a message fired both
                // handlers in the same frame (count++ AND last.content
                // changed) and the competing animated vs. instant scroll
                // commands produced a visible "jump then snap back". One
                // instant scroll is enough — the new bubble simply lands
                // at the bottom without any overshoot animation.
                .onChange(of: viewModel.messages.last?.content) { _, _ in
                    proxy.scrollTo(bottomAnchorId, anchor: .bottom)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    proxy.scrollTo(bottomAnchorId, anchor: .bottom)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            // Input area
            if viewModel.isLimitReached {
                limitReachedBar
            } else {
                inputArea
            }
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadConversation()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.recoverFromBackground() }
            }
        }
        .analyticsScreen("CoachChat")
    }

    // MARK: - Welcome Section

    /// Rendered as the coach's first message in an empty conversation —
    /// same bubble as real replies, but purely client-side (never sent
    /// to the server, costs no tokens, not persisted).
    private var welcomeSection: some View {
        CoachMessageBubble(
            message: CoachMessageResponse(
                id: "local-welcome",
                role: "assistant",
                content: String(localized: "coach.welcome"),
                session: nil,
                createdAt: Date()
            ),
            onStartWorkout: {},
            onRegenerate: {}
        )
    }

    // MARK: - Limit Reached Bar

    private var limitReachedBar: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.subscriptionManager.showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Upgrade to Premium")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.gymBroPrimaryGradient)
                .cornerRadius(24)
            }
            .padding(.horizontal, 16)

            Text("Unlock unlimited AI coaching conversations")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
        }
        .padding(.vertical, 12)
        .background(Color.gymBroBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gymBroNeutral100)
                .frame(height: 1)
        }
        .padding(.bottom, sessionManager.isCollapsed ? 72 : 0)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 12) {
            // Quick action cards
            if viewModel.messages.isEmpty || !viewModel.isStreaming {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.quickActions, id: \.self) { action in
                            Button {
                                Task {
                                    await viewModel.handleQuickAction(action)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: quickActionIcon(for: action))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gymBroPrimary)
                                    Text(action)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gymBroTextPrimary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gymBroNeutral100, lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                            }
                            .disabled(viewModel.isStreaming)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Text input + send button
            HStack(alignment: .bottom, spacing: 10) {
                TextEditor(text: $viewModel.inputText)
                    .font(.gymBroSmall)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(minHeight: 40, maxHeight: 120)
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollContentBackground(.hidden)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gymBroNeutral100, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if viewModel.inputText.isEmpty {
                            Text("Ask your coach anything...")
                                .font(.gymBroSmall)
                                .foregroundColor(Color(.placeholderText))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    Circle()
                        .fill(Color.gymBroPrimaryGradient)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(45))
                        )
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
                .opacity(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color.gymBroBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gymBroNeutral100)
                .frame(height: 1)
        }
        .padding(.bottom, sessionManager.isCollapsed ? 72 : 0)
    }

    // MARK: - Quick Action Icons

    private func quickActionIcon(for action: String) -> String {
        switch action {
        case "Build my plan": return "calendar.badge.plus"
        case "Create today's workout": return "figure.strengthtraining.traditional"
        case "Swap an exercise": return "arrow.triangle.2.circlepath"
        case "Make it shorter": return "clock.arrow.circlepath"
        case "I only have dumbbells": return "dumbbell.fill"
        default: return "sparkles"
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 4.0
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.gymBroTextSecondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                        .offset(y: sin(phase + Double(index) * 0.8) * 3)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(BubbleShape(isUser: false))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    CoachChatView()
        .environmentObject(
            ActiveSessionManager(
                appDataState: DependencyContainer.shared.resolve(AppDataState.self),
                liveActivityService: LiveActivityService(),
            ),
        )
}
