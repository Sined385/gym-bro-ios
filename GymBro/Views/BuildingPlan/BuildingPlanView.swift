//
//  BuildingPlanView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-31.
//

import SwiftUI
import Combine

struct BuildingPlanView: View {

    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var homeViewModel: HomeViewModel = DependencyContainer.shared.resolve(HomeViewModel.self)

    // MARK: - Animation State

    @State private var progress: Double = 0
    @State private var currentStep: Int = 0
    @State private var completedSteps: Set<Int> = []
    @State private var animationsFinished = false
    @State private var dashboardLoaded = false
    @State private var iconRotation: Double = 0
    @State private var shimmerOffset: CGFloat = -1
    @State private var pulseScale: CGFloat = 1.0
    @State private var sparkleOpacities: [Double] = [0, 0, 0, 0, 0]
    @State private var tip: String = ""

    // MARK: - Constants

    private let steps: [(icon: String, label: String)] = [
        ("target", "Analyzing your goals"),
        ("dumbbell.fill", "Selecting exercises"),
        ("calendar", "Building weekly schedule"),
        ("bolt.fill", "Optimizing intensity"),
        ("trophy.fill", "Setting milestones"),
        ("chart.line.uptrend.xyaxis", "Finalizing your plan"),
    ]

    private let tips = [
        "Consistency beats perfection. Show up, even on tough days!",
        "Rest days are growth days. Your muscles rebuild while you recover.",
        "Progressive overload is key — small increases add up to big gains.",
        "Hydration affects performance more than you think. Drink up!",
        "Sleep is the most underrated performance enhancer.",
    ]

    private let stepDuration: Double = 1.2
    private let totalAnimationTime: Double = 7.2 // 6 steps × 1.2s

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 48)

                heroIcon
                    .padding(.bottom, 24)

                titleSection
                    .padding(.bottom, 40)

                progressBar
                    .padding(.horizontal, 26)
                    .padding(.bottom, 32)

                stepsCard
                    .padding(.horizontal, 26)

                Spacer()

                tipSection
                    .padding(.horizontal, 26)
                    .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
        .task {
            tip = tips.randomElement() ?? tips[0]
            await startAnimations()
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "F8F9FA"),
                    Color(hex: "FAFBFC"),
                    Color(hex: "F5F6F8"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Pink ambient blur
            Circle()
                .fill(Color.gymBroPrimary.opacity(0.05))
                .frame(width: 289, height: 289)
                .blur(radius: 64)
                .offset(x: -80, y: -200)

            // Green ambient blur
            Circle()
                .fill(Color(hex: "30C08D").opacity(0.05))
                .frame(width: 301, height: 301)
                .blur(radius: 64)
                .offset(x: 40, y: 200)
        }
    }

    // MARK: - Hero Icon

    private var heroIcon: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.gymBroPrimary.opacity(0.2), Color.gymBroPrimaryDark.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 99, height: 99)
                .opacity(0.53)

            // White container
            Circle()
                .fill(Color.white)
                .frame(width: 96, height: 96)
                .shadow(color: Color.gymBroPrimary.opacity(0.15), radius: 20, x: 0, y: 10)

            // Pink inner circle with icon
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.gymBroPrimary, .gymBroPrimaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(iconRotation))

            Image(systemName: "dumbbell.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .rotationEffect(.degrees(iconRotation))

            // Sparkle particles
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.gymBroPrimary, .gymBroPrimaryDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: sparkleSize(i), height: sparkleSize(i))
                    .offset(sparkleOffset(i))
                    .opacity(sparkleOpacities[i])
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                iconRotation = 360
            }
            animateSparkles()
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Building Your Plan")
                .font(.system(size: 30, weight: .black))
                .tracking(-0.35)
                .foregroundColor(.gymBroNeutral900)

            Text("Our AI coach is crafting a personalized program just for you...")
                .font(.system(size: 16, weight: .medium))
                .tracking(-0.31)
                .foregroundColor(Color(hex: "737373"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
                        )

                    // Fill
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [.gymBroPrimary, .gymBroPrimaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progress), height: 10)
                        .padding(1)
                        .overlay(
                            // Shimmer
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.clear,
                                            Color.white.opacity(0.3),
                                            Color.clear,
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 60)
                                .offset(x: geo.size.width * shimmerOffset)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        )
                }
            }
            .frame(height: 12)

            // Labels
            HStack {
                Text("Generating...")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "A1A1A1"))

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gymBroPrimary)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.5
            }
        }
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        VStack(spacing: 16) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                stepRow(index: index, icon: step.icon, label: step.label)
            }
        }
        .padding(25)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 25, x: 0, y: 10)
        )
    }

    private func stepRow(index: Int, icon: String, label: String) -> some View {
        let isCompleted = completedSteps.contains(index)
        let isActive = currentStep == index && !isCompleted

        return HStack(spacing: 16) {
            // Icon container
            ZStack {
                if isActive {
                    // Pulsing glow
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.gymBroPrimary, .gymBroPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 53, height: 53)
                        .opacity(0.37)
                        .scaleEffect(pulseScale)
                }

                RoundedRectangle(cornerRadius: 16)
                    .fill(iconBackground(isCompleted: isCompleted, isActive: isActive))
                    .frame(width: 48, height: 48)
                    .shadow(
                        color: iconShadowColor(isCompleted: isCompleted, isActive: isActive),
                        radius: 3, x: 0, y: 4
                    )

                Image(systemName: isCompleted ? "checkmark" : icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isCompleted || isActive ? .white : Color(hex: "A1A1A1"))
            }
            .frame(width: 53, height: 53)

            // Label
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .tracking(-0.31)
                .foregroundColor(isCompleted || isActive ? .gymBroNeutral900 : Color(hex: "A1A1A1"))

            Spacer()

            // Status indicator
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "30C08D"))
                    .transition(.scale.combined(with: .opacity))
            } else if isActive {
                LoadingDots()
                    .transaction { $0.animation = nil }
            }
        }
        .frame(height: 53)
    }

    // MARK: - Tip Section

    private var tipSection: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\u{1F4A1}")
                .font(.system(size: 14))

            Text("Tip: \(tip)")
                .font(.system(size: 14, weight: .medium))
                .italic()
                .tracking(-0.15)
                .foregroundColor(Color(hex: "A1A1A1"))
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Animation Logic

    private func startAnimations() async {
        // Start dashboard load in background
        Task {
            await homeViewModel.loadDashboard()
            dashboardLoaded = true
            checkTransition()
        }

        // Start pulse animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.08
        }

        // Animate through each step
        for stepIndex in 0..<steps.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = stepIndex
            }

            // Progress animation for this step
            let targetProgress = Double(stepIndex + 1) / Double(steps.count)
            withAnimation(.easeInOut(duration: stepDuration * 0.8)) {
                progress = targetProgress
            }

            // Wait for step duration
            try? await Task.sleep(for: .milliseconds(Int(stepDuration * 1000)))

            // Mark step as completed
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                completedSteps.insert(stepIndex)
            }
        }

        // Small delay after final step completes
        try? await Task.sleep(for: .milliseconds(600))

        animationsFinished = true
        checkTransition()
    }

    private func checkTransition() {
        guard animationsFinished && dashboardLoaded else { return }

        // Mark as loaded so HomeView doesn't re-trigger loadDashboard
        homeViewModel.markAsLoaded()

        withAnimation(.easeInOut(duration: 0.3)) {
            coordinator.navigate(to: .home)
        }
    }

    private func animateSparkles() {
        for i in 0..<5 {
            let delay = Double(i) * 0.3
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(delay)) {
                sparkleOpacities[i] = [0.52, 0.21, 0.06, 0.35, 0.15][i]
            }
        }
    }

    // MARK: - Helpers

    private func iconBackground(isCompleted: Bool, isActive: Bool) -> LinearGradient {
        if isCompleted {
            return LinearGradient(
                colors: [Color(hex: "30C08D"), Color(hex: "28A878")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isActive {
            return LinearGradient(
                colors: [.gymBroPrimary, .gymBroPrimaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "F5F5F5"), Color(hex: "F5F5F5")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func iconShadowColor(isCompleted: Bool, isActive: Bool) -> Color {
        if isCompleted {
            return Color(hex: "30C08D").opacity(0.2)
        } else if isActive {
            return Color.gymBroPrimary.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    private func sparkleSize(_ index: Int) -> CGFloat {
        [5, 4, 3, 6, 4][index]
    }

    private func sparkleOffset(_ index: Int) -> CGSize {
        [
            CGSize(width: -52, height: -20),
            CGSize(width: 48, height: -30),
            CGSize(width: 55, height: 15),
            CGSize(width: -45, height: 25),
            CGSize(width: 30, height: -50),
        ][index]
    }
}

// MARK: - Loading Dots

private struct LoadingDots: View {
    var body: some View {
        PhaseAnimator([0, 1, 2]) { phase in
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.gymBroPrimary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(phase == i ? 1.4 : 1.0)
                        .opacity(phase == i ? 0.9 : 0.3)
                        .offset(y: phase == i ? -3 : 0)
                }
            }
        } animation: { _ in
            .easeInOut(duration: 0.35)
        }
    }
}
