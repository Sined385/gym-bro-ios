//
//  AuthenticationView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI
import Combine
import AuthenticationServices

/// First onboarding screen - User authentication
struct AuthenticationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject private var coordinator: AppCoordinator

    /// When true, renders as standalone (with own progress bar + footer).
    /// When false, renders just the content area (container provides progress + footer).
    var isStandalone: Bool = false

    @State private var appleSignInDelegate: AppleSignInDelegate?

    var body: some View {
        Group {
            if isStandalone {
                standaloneLayout
            } else {
                embeddedContent
            }
        }
        .analyticsScreen("Authentication")
    }

    // MARK: - Standalone Layout (used from GymBroApp directly)

    private var standaloneLayout: some View {
        ZStack {
            Color.gymBroBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress section
                VStack(spacing: 16) {
                    HStack {
                        Text("WELCOME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "737373"))
                            .tracking(0.6)

                        Spacer()

                        Text("13%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gymBroPrimary)
                            .tracking(-0.31)
                    }

                    StepProgressBar(progress: 0.125)
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 32)

                // Scrollable content with inline buttons
                ScrollView {
                    VStack(spacing: 32) {
                        embeddedContent

                        authButtons
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - Embedded Content (used inside OnboardingContainerView)

    private var embeddedContent: some View {
        VStack(spacing: 32) {
            // Header
            StepHeader(
                icon: "person.crop.rectangle",
                title: "Create your account"
            )

            // Center content
            VStack(spacing: 12) {
                Spacer()
                    .frame(height: 40)

                // Person icon in a bordered circle
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 112, height: 112)
                        .overlay(
                            Circle()
                                .stroke(Color.gymBroPrimary.opacity(0.1), lineWidth: 4)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)

                    Image(systemName: "person.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.gymBroPrimary)
                }

                Spacer()
                    .frame(height: 12)

                // Heading
                Text("Your AI Fitness Coach")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.gymBroNeutral900)
                    .tracking(-0.53)
                    .multilineTextAlignment(.center)

                // Description
                Text("Sync your personalized plans, PRs, and AI insights across all your devices.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "737373"))
                    .tracking(-0.31)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 260)

                Spacer()
                    .frame(height: 20)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Auth Buttons (inline in scroll content)

    private var authButtons: some View {
        VStack(spacing: 12) {
            // Apple Sign-In
            Button(action: handleAppleSignIn) {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Continue with Apple")
                        .font(.system(size: 17, weight: .bold))
                        .tracking(-0.43)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color.black)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 8)
            }
            .disabled(authViewModel.isLoading)

            // Google Sign-In
            Button(action: handleGoogleSignIn) {
                HStack(spacing: 8) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Continue with Google")
                        .font(.system(size: 17, weight: .bold))
                        .tracking(-0.43)
                }
                .foregroundColor(.gymBroNeutral900)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.white)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gymBroNeutral200, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            }
            .disabled(authViewModel.isLoading)

            #if DEBUG
            // Dev Sign-In (mock, no Supabase needed)
            Button(action: handleMockSignIn) {
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Dev Sign-In")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-0.43)
                }
                .foregroundColor(.gymBroNeutral600)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.gymBroNeutral100)
                .cornerRadius(20)
            }
            .disabled(authViewModel.isLoading)
            #endif

            // Loading indicator
            if authViewModel.isLoading {
                ProgressView()
                    .tint(.gymBroPrimary)
            }

            // Terms disclaimer
            Text("By continuing, you agree to our Terms of Service.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "A1A1A1"))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    // MARK: - Actions

    private func handleAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let delegate = AppleSignInDelegate { [authViewModel, coordinator] authorization in
            Task { @MainActor in
                await authViewModel.signInWithApple(authorization)
                if authViewModel.isAuthenticated {
                    await coordinator.handleAuthenticationSuccess()
                }
            }
        }
        appleSignInDelegate = delegate

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
    }

    #if DEBUG
    private func handleMockSignIn() {
        Task {
            await authViewModel.mockSignIn()
            await coordinator.handleAuthenticationSuccess()
        }
    }
    #endif

    private func handleGoogleSignIn() {
        Task {
            await authViewModel.signInWithGoogle()
            if authViewModel.isAuthenticated {
                await coordinator.handleAuthenticationSuccess()
            }
        }
    }
}

// MARK: - Apple Sign-In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let onSuccess: (ASAuthorization) -> Void

    init(onSuccess: @escaping (ASAuthorization) -> Void) {
        self.onSuccess = onSuccess
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onSuccess(authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
            return // User cancelled — no error to show
        }
        print("Apple Sign-In error: \(error.localizedDescription)")
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
