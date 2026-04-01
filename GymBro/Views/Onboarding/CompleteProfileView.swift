//
//  CompleteProfileView.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import SwiftUI

/// Onboarding step for completing user profile (avatar, name, username)
struct CompleteProfileView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showImagePicker = false

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(icon: "person.crop.circle.fill", title: "Complete Your Profile")

            // Avatar picker
            VStack(spacing: 8) {
                Button {
                    showImagePicker = true
                } label: {
                    avatarContent
                }

                Text("Optional - you can skip this")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gymBroTextSecondary)
            }

            // Display Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)

                TextField("e.g., Alex Martinez", text: Binding(
                    get: { viewModel.displayName },
                    set: { viewModel.updateDisplayName($0) }
                ))
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.gymBroCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(hex: "E5E5E5")
                                : Color.gymBroPrimary.opacity(0.5),
                            lineWidth: 1
                        )
                )
                .cornerRadius(12)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            }

            // Username
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)

                HStack(spacing: 0) {
                    Text("@")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymBroTextSecondary)
                        .padding(.leading, 16)

                    TextField("username", text: Binding(
                        get: { viewModel.username },
                        set: { viewModel.updateUsername($0) }
                    ))
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 14)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    // Status indicator
                    if viewModel.isCheckingUsername {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 12)
                    } else if let available = viewModel.usernameAvailable, viewModel.username.count >= 3 {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(available ? Color(hex: "30C08D") : Color(hex: "E86A75"))
                            .padding(.trailing, 12)
                    }
                }
                .background(Color.gymBroCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(usernameFieldBorderColor, lineWidth: 1)
                )
                .cornerRadius(12)

                if let error = viewModel.usernameError {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "E86A75"))
                } else {
                    Text("Letters, numbers, and underscores only")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }
            }

        }
        .imageSourcePicker(isPresented: $showImagePicker) { data in
            viewModel.setAvatarImage(data)
        }
        .task {
            await viewModel.prefillFromAuth()
        }
    }

    // MARK: - Avatar Content

    @ViewBuilder
    private var avatarContent: some View {
        if let imageData = viewModel.avatarImageData, let uiImage = UIImage(data: imageData) {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(hex: "F5F5F5"), lineWidth: 3))

                ZStack {
                    Circle()
                        .fill(Color.gymBroPrimary)
                        .frame(width: 28, height: 28)
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: -2, y: -2)
            }
        } else {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "F5F5F5"))
                        .frame(width: 100, height: 100)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }

                Text("ADD PHOTO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gymBroPrimary)
                    .tracking(0.5)
            }
        }
    }

    // MARK: - Helpers

    private var usernameFieldBorderColor: Color {
        if viewModel.usernameError != nil {
            return Color(hex: "E86A75")
        }
        if viewModel.usernameAvailable == true && viewModel.username.count >= 3 {
            return Color(hex: "30C08D")
        }
        if viewModel.username.isEmpty {
            return Color(hex: "E5E5E5")
        }
        return Color.gymBroPrimary.opacity(0.5)
    }
}
