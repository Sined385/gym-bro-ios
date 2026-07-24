//
//  PromoCodeRedeemView.swift
//  GymBro
//
//  Promo-code redemption, shared by the post-onboarding offer (shown
//  before the paywall) and the Settings entry point.
//

import SwiftUI

struct PromoCodeRedeemView: View {

    enum Context {
        /// Full-screen step after plan building — offers Skip; skipping
        /// (or failing) chains into the paywall via the cover's onDismiss.
        case postOnboarding
        /// Settings sheet — offers Cancel, no paywall chaining.
        case settings
    }

    let context: Context
    /// Called on any exit; `redeemed` is true when a code was activated.
    var onFinished: (_ redeemed: Bool) -> Void

    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var code: String = ""
    @State private var isRedeeming = false
    @State private var errorMessage: String?
    @State private var grantedUntil: Date??  = nil // .some(nil) = success, unknown date

    private var didRedeem: Bool { grantedUntil != nil }

    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)

                // Gift glyph
                ZStack {
                    Circle()
                        .fill(Color.gymBroPrimary.opacity(0.1))
                        .frame(width: 96, height: 96)
                    Image(systemName: didRedeem ? "checkmark.seal.fill" : "giftcard.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.gymBroPrimary)
                }

                VStack(spacing: 8) {
                    Text(didRedeem ? "You're in!" : "Have a promo code?")
                        .font(.system(size: 26, weight: .black))
                        .tracking(-0.5)
                        .foregroundColor(.gymBroNeutral900)

                    Text(didRedeem ? successSubtitle : "Enter it below to unlock GymJam Premium.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if !didRedeem {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("PROMO CODE", text: $code)
                            .font(.system(size: 20, weight: .bold))
                            .tracking(1.5)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .disabled(isRedeeming)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        errorMessage == nil ? Color.gymBroNeutral200 : Color.red.opacity(0.5),
                                        lineWidth: 1.5
                                    )
                            )
                            .onChange(of: code) { errorMessage = nil }

                        if let errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // CTA
                Button {
                    if didRedeem {
                        onFinished(true)
                    } else {
                        redeem()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRedeeming {
                            ProgressView().tint(.white)
                        }
                        Text(didRedeem ? "Continue" : "Redeem")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        canSubmit || didRedeem
                            ? LinearGradient(
                                colors: [.gymBroPrimary, .gymBroPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gymBroNeutral400, Color.gymBroNeutral400],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .disabled((!canSubmit && !didRedeem) || isRedeeming)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color.gymBroBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !didRedeem {
                        Button(context == .postOnboarding ? "Skip" : "Cancel") {
                            onFinished(false)
                        }
                        .foregroundColor(.gymBroTextSecondary)
                    }
                }
            }
        }
        .interactiveDismissDisabled(context == .postOnboarding)
        .analyticsScreen("PromoCodeRedeem")
    }

    private var canSubmit: Bool {
        !trimmedCode.isEmpty && !isRedeeming
    }

    private var successSubtitle: String {
        if case .some(.some(let date)) = grantedUntil {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            return "Premium is active until \(formatter.string(from: date))."
        }
        return "Premium is now active on your account."
    }

    private func redeem() {
        guard canSubmit else { return }
        isRedeeming = true
        errorMessage = nil
        Task {
            let result = await subscriptionManager.redeemPromoCode(trimmedCode)
            isRedeeming = false
            switch result {
            case .success(let expiresAt):
                grantedUntil = .some(expiresAt)
            case .failure(let message):
                errorMessage = message
            }
        }
    }
}
