//
//  MainTabView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-13.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @State private var hasAttemptedRestore = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                TrainingPlanView()
                    .tabItem {
                        Label("Plan", systemImage: "calendar")
                    }

                CoachChatView()
                    .tabItem {
                        Label("GymJam", systemImage: "bubble.left.and.text.bubble.right.fill")
                    }

                CommunityFeedView()
                    .tabItem {
                        Label("Community", systemImage: "person.2.fill")
                    }

                MyProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
            }
            .tint(Color(hex: "E86A75"))
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
