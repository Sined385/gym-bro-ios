//
//  SettingsView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-25.
//

import SwiftUI
import Combine

struct SettingsView: View {

    @StateObject private var viewModel: SettingsViewModel = DependencyContainer.shared.resolve(SettingsViewModel.self)
    @ObservedObject private var subscriptionManager: SubscriptionManager = DependencyContainer.shared.resolve(SubscriptionManager.self)
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var showAboutYouEditor = false
    @State private var showPromoCodeSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    subscriptionSection
                    preferencesSection
                    accountSection
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .task {
            await viewModel.loadSettings()
        }
        .sheet(isPresented: $showAboutYouEditor) {
            AboutYouEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPromoCodeSheet) {
            PromoCodeRedeemView(context: .settings) { _ in
                showPromoCodeSheet = false
            }
            .environmentObject(subscriptionManager)
        }
        .analyticsScreen("Settings")
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            HStack {
                Button { dismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)

                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUBSCRIPTION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "A1A1A1"))
                .tracking(0.5)

            if subscriptionManager.isPremium {
                // Premium active
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.gymBroPrimary.opacity(0.1))
                            .frame(width: 44, height: 44)

                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gymBroPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("GymJam Premium")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)

                        Text(premiumStatusLine)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "30C08D"))
                    }

                    Spacer()

                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Manage")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gymBroPrimary)
                    }
                }
                .padding(16)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gymBroPrimary.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            } else {
                // Free tier — upgrade CTA
                Button {
                    subscriptionManager.showPaywall = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.gymBroPrimary.opacity(0.1))
                                .frame(width: 44, height: 44)

                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gymBroPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gymBroNeutral900)

                            Text("Unlock unlimited AI coaching & more")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "D4D4D4"))
                    }
                    .padding(16)
                }
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
                )
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            }

            // Promo code — free users, and promo-premium users who can
            // extend by stacking another code. StoreKit/admin premium is
            // blocked server-side, so hide the row for them.
            if !subscriptionManager.isPremium || subscriptionManager.premiumSource == "promo" {
                Button {
                    showPromoCodeSheet = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.gymBroPrimary.opacity(0.1))
                                .frame(width: 44, height: 44)

                            Image(systemName: "giftcard.fill")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.gymBroPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Redeem promo code")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gymBroNeutral900)

                            Text(subscriptionManager.premiumSource == "promo"
                                ? "Extend your Premium access"
                                : "Unlock Premium with a code")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "D4D4D4"))
                    }
                    .padding(16)
                }
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
                )
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            }
        }
    }

    /// "Active" — or "Premium until {date}" for expiring (promo) premium.
    private var premiumStatusLine: String {
        if subscriptionManager.premiumSource == "promo",
           let until = subscriptionManager.premiumExpiresAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return String(localized: "Premium until \(formatter.string(from: until))")
        }
        return "Active"
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PREFERENCES")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "A1A1A1"))
                .tracking(0.5)

            VStack(spacing: 0) {
                // Rest Time Between Sets
                restTimeSettingsRow

                Divider()
                    .padding(.leading, 60)

                // About You — AI coach context
                aboutYouRow

                Divider()
                    .padding(.leading, 60)

                // Push Notifications
                settingsRow(
                    icon: "bell",
                    iconBgColor: Color(red: 232/255, green: 106/255, blue: 117/255, opacity: 0.1),
                    iconColor: .gymBroPrimary,
                    title: "Push Notifications",
                    subtitle: "Get notified about activity",
                    toggle: $viewModel.pushNotificationsEnabled,
                    onToggle: { newValue in
                        Task { await viewModel.togglePushNotifications(enabled: newValue) }
                    }
                )

                Divider()
                    .padding(.leading, 60)

                // Share Progress Data
                settingsRow(
                    icon: "square.and.arrow.up",
                    iconBgColor: Color(red: 122/255, green: 130/255, blue: 246/255, opacity: 0.1),
                    iconColor: Color(red: 122/255, green: 130/255, blue: 246/255),
                    title: "Share Progress Data",
                    subtitle: "Allow friends to see your workout progress and achievements",
                    toggle: $viewModel.shareProgressData,
                    onToggle: nil
                )
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
            )
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)

        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "A1A1A1"))
                .tracking(0.5)

            // Log Out card
            Button {
                Task {
                    await viewModel.signOut()
                    await coordinator.handleSignOut()
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 45/255, green: 50/255, blue: 64/255, opacity: 0.1))
                            .frame(width: 44, height: 44)

                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "2D3240"))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log Out")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)

                        Text("Sign out of your account")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                    }

                    Spacer()
                }
                .padding(16)
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
            )
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)

            // Delete Account card
            Button {
                viewModel.showDeleteConfirmation = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FEF2F2"))
                            .frame(width: 44, height: 44)

                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "FB2C36"))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "FB2C36"))

                        Text("Permanently delete your account and data")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                    }

                    Spacer()
                }
                .padding(16)
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
            )
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .alert("Delete Account", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        try? await viewModel.deleteAccount()
                        await coordinator.handleSignOut()
                    }
                }
            } message: {
                Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Version 1.0.0")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "A1A1A1"))

            Text("Made with heart for fitness enthusiasts")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "D4D4D4"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    // MARK: - About You Row

    private var aboutYouRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showAboutYouEditor = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 122/255, green: 130/255, blue: 246/255, opacity: 0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(red: 122/255, green: 130/255, blue: 246/255))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("About You")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                        Text("Free-form context the AI uses for every plan")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "D4D4D4"))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Inline preview of the saved note — only when non-empty.
            if !viewModel.aiCoachContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                aboutYouPreviewCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    private var aboutYouPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.aiCoachContext)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gymBroNeutral900)
                .lineSpacing(2)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(Color(hex: "F5F5F5"))

            HStack {
                Text("\(viewModel.aiCoachContext.count) / 500")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "A1A1A1"))
                    .monospacedDigit()
                Spacer()
                Button("Edit") { showAboutYouEditor = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroPrimary)
            }
        }
        .padding(14)
        .background(Color.gymBroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - Rest Time Settings Row

    private var restTimeSettingsRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 255/255, green: 149/255, blue: 0/255, opacity: 0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 255/255, green: 149/255, blue: 0))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest Between Sets")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)

                Text(viewModel.preferredRestTime.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gymBroTextSecondary)
            }

            Spacer()

            // Inline stepper with duration between buttons
            HStack(spacing: 10) {
                Button {
                    stepRestTime(by: -30)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(canDecrementRestTime ? .gymBroPrimary : Color(hex: "D4D4D4"))
                        .frame(width: 32, height: 32)
                        .background(canDecrementRestTime ? Color.gymBroPrimary.opacity(0.1) : Color(hex: "F5F5F5"))
                        .clipShape(Circle())
                }
                .disabled(!canDecrementRestTime)

                Text(formatRestTime(viewModel.preferredRestTime.rawValue))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .monospacedDigit()
                    .frame(minWidth: 40)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: viewModel.preferredRestTime)

                Button {
                    stepRestTime(by: 30)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(canIncrementRestTime ? .gymBroPrimary : Color(hex: "D4D4D4"))
                        .frame(width: 32, height: 32)
                        .background(canIncrementRestTime ? Color.gymBroPrimary.opacity(0.1) : Color(hex: "F5F5F5"))
                        .clipShape(Circle())
                }
                .disabled(!canIncrementRestTime)
            }
        }
        .padding(16)
    }

    private var canDecrementRestTime: Bool {
        viewModel.preferredRestTime.rawValue > 30
    }

    private var canIncrementRestTime: Bool {
        viewModel.preferredRestTime.rawValue < 300
    }

    private func stepRestTime(by delta: Int) {
        let newValue = viewModel.preferredRestTime.rawValue + delta
        if let restTime = RestTime(rawValue: newValue) {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.updateRestTime(restTime)
            }
        }
    }

    private func formatRestTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        if s == 0 { return "\(m):00" }
        return "\(m):\(String(format: "%02d", s))"
    }

    // MARK: - Settings Row Helper

    private func settingsRow(
        icon: String,
        iconBgColor: Color,
        iconColor: Color,
        title: String,
        subtitle: String,
        toggle: Binding<Bool>,
        onToggle: ((Bool) -> Void)?
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gymBroTextSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { toggle.wrappedValue },
                set: { newValue in
                    toggle.wrappedValue = newValue
                    onToggle?(newValue)
                }
            ))
            .labelsHidden()
            .tint(Color(hex: "30C08D"))
        }
        .padding(16)
    }
}
