//
//  SuggestedProfilesSection.swift
//  GymBro
//

import SwiftUI

struct SuggestedProfilesSection: View {
    let users: [SuggestedUser]
    let onFollow: (String) -> Void
    let onUserTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested for you")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gymBroNeutral900)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(users) { user in
                        suggestedCard(user)
                            .onTapGesture { onUserTap(user.id) }
                    }
                }
                // Each card has a soft shadow that extends ~6pt past its
                // frame; without breathing room the ScrollView clips it
                // top and bottom. Vertical padding inside the scrollable
                // content keeps the shadow whole, horizontal padding
                // aligns the first/last card with the section title.
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }
        }
    }

    private func suggestedCard(_ user: SuggestedUser) -> some View {
        VStack(spacing: 8) {
            AvatarView(
                name: user.fullName,
                avatarUrl: user.avatarUrl,
                size: 56
            )

            Text(user.fullName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gymBroNeutral900)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(user.sessionCount) workouts")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)

            Button {
                onFollow(user.id)
            } label: {
                Text("Follow")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.gymBroPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 120)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(Color.gymBroCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "2D3240").opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
