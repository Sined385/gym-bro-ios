//
//  MainTabView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-13.
//

import SwiftUI
import Combine

struct MainTabView: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @EnvironmentObject var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject var appDataState: AppDataState
    @ObservedObject private var subscriptionManager: SubscriptionManager = DependencyContainer.shared.resolve(SubscriptionManager.self)
    @State private var hasAttemptedRestore = false
    @State private var selectedTab = 0
    @State private var showSharedTemplateSheet = false
    @State private var sharedTemplateCode: String?
    @State private var isKeyboardVisible = false

    private let analyticsService: AnalyticsTrackingServiceProtocol = {
        DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)
    }()

    private let tabNames = ["Home", "Plan", "GymJam", "Community", "Profile"]

    private func handleDeepLink(_ link: DeepLink?) {
        guard let link else { return }
        switch link {
        case .sharedTemplate(let code):
            sharedTemplateCode = code
            showSharedTemplateSheet = true
        case .post(let postId):
            selectedTab = 3
            deepLinkRouter.pendingPostId = postId
        case .userProfile(let userId):
            selectedTab = 3
            deepLinkRouter.pendingUserId = userId
        case .skipRest:
            sessionManager.skipRestTimer()
        case .repeatLastSet:
            sessionManager.expand()
            sessionManager.requestRepeatLastSet()
            sessionManager.startRestTimer()
        }
        deepLinkRouter.clearDeepLink()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                TrainingPlanView()
                    .tabItem {
                        Label("Plan", systemImage: "calendar")
                    }
                    .tag(1)

                CoachChatView()
                    .tabItem {
                        Label("GymJam", systemImage: "bubble.left.and.text.bubble.right.fill")
                    }
                    .tag(2)

                CommunityFeedView()
                    .tabItem {
                        Label("Community", systemImage: "person.2.fill")
                    }
                    .tag(3)

                MyProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(4)
            }
            .tint(Color(hex: "E86A75"))
            .onChange(of: selectedTab) { _, newTab in
                if newTab < tabNames.count {
                    analyticsService.trackTabSwitch(tab: tabNames[newTab])
                }
            }
            .toolbar(sessionManager.isExpanded ? .hidden : .visible, for: .tabBar)

            if sessionManager.isSessionActive {
                // Full session overlay — kept alive via opacity toggle, NOT conditional removal
                SessionFlowContainer(
                    sessionId: sessionManager.sessionId ?? "",
                    sessionTitle: sessionManager.sessionTitle ?? "",
                    initialExercises: sessionManager.sessionExercises,
                    restoredExercises: sessionManager.restoredExercises,
                    restoredFeedback: sessionManager.restoredFeedback,
                    onCollapse: { sessionManager.collapse() },
                    onDismiss: { sessionManager.endSession() }
                )
                .id(sessionManager.sessionId)
                .opacity(sessionManager.isExpanded ? 1 : 0)
                .allowsHitTesting(sessionManager.isExpanded)
                .ignoresSafeArea()

                // Mini-player bar when collapsed
                if sessionManager.isCollapsed {
                    VStack {
                        Spacer()
                        SessionMiniPlayerBar()
                            .padding(.horizontal, 16)
                            .padding(.bottom, isKeyboardVisible ? 0 : 49)
                    }
                    .allowsHitTesting(true)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Conflict overlay — inside ZStack, above everything
            if sessionManager.showSessionConflict {
                SessionConflictOverlay()
                    .environmentObject(sessionManager)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: sessionManager.presentationState)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sessionManager.showSessionConflict)
        .task {
            guard !hasAttemptedRestore else { return }
            hasAttemptedRestore = true
            sessionManager.restoreSessionIfNeeded()
        }
        .onAppear {
            handleDeepLink(deepLinkRouter.pendingDeepLink)
        }
        .onChange(of: deepLinkRouter.pendingDeepLink) { _, newValue in
            handleDeepLink(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .sheet(isPresented: $showSharedTemplateSheet) {
            if let code = sharedTemplateCode {
                SharedTemplatePreviewView(shareCode: code)
                    .environmentObject(sessionManager)
            }
        }
        // Post-workout share screen — appears after the session is fully torn
        // down on the server, so dismissing it (or force-quitting from it) has
        // zero effect on session state. Purely an optional add-on.
        .sheet(item: $appDataState.pendingShareData) { data in
            ShareSessionView(
                data: data,
                onShare: { _ in appDataState.pendingShareData = nil },
                onSkip: { appDataState.pendingShareData = nil }
            )
        }
        .fullScreenCover(isPresented: $subscriptionManager.showPaywall) {
            NavigationStack {
                PaywallView()
                    .environmentObject(subscriptionManager)
            }
        }
        .task {
            await subscriptionManager.loadStatus()
        }
    }
}

// MARK: - Placeholder Views

struct SchedulePlaceholderView: View {
    var body: some View {
        ZStack {
            Color.gymBroBackground
                .ignoresSafeArea()

            Text("Schedule")
                .font(.gymBroHeaderLarge)
                .foregroundColor(.gymBroTextPrimary)
        }
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        ZStack {
            Color.gymBroBackground
                .ignoresSafeArea()

            Text("Profile")
                .font(.gymBroHeaderLarge)
                .foregroundColor(.gymBroTextPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .inject(dependencies: .shared)
}
