//
//  MainTabView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-13.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @EnvironmentObject var deepLinkRouter: DeepLinkRouter
    @State private var hasAttemptedRestore = false
    @State private var selectedTab = 0
    @State private var showSharedTemplateSheet = false
    @State private var sharedTemplateCode: String?

    private let analyticsService: AnalyticsTrackingServiceProtocol = {
        DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)
    }()

    private let tabNames = ["Home", "Plan", "GymJam", "Community", "Profile"]

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
            .safeAreaInset(edge: .bottom) {
                if sessionManager.isCollapsed {
                    Color.clear.frame(height: 64)
                }
            }

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
                            .padding(.bottom, 49)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: sessionManager.presentationState)
        .task {
            guard !hasAttemptedRestore else { return }
            hasAttemptedRestore = true
            sessionManager.restoreSessionIfNeeded()
        }
        .onAppear {
            if case .sharedTemplate(let code) = deepLinkRouter.pendingDeepLink {
                sharedTemplateCode = code
                showSharedTemplateSheet = true
                deepLinkRouter.clearDeepLink()
            }
        }
        .onChange(of: deepLinkRouter.pendingDeepLink) { _, newValue in
            if case .sharedTemplate(let code) = newValue {
                sharedTemplateCode = code
                showSharedTemplateSheet = true
                deepLinkRouter.clearDeepLink()
            }
        }
        .sheet(isPresented: $showSharedTemplateSheet) {
            if let code = sharedTemplateCode {
                SharedTemplatePreviewView(shareCode: code)
                    .environmentObject(sessionManager)
            }
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
