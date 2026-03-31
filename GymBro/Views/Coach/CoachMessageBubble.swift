//
//  CoachMessageBubble.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import SwiftUI

struct CoachMessageBubble: View {
    let message: CoachMessageResponse
    let onStartWorkout: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Text content
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.gymBroSmall)
                        .foregroundColor(message.isUser ? .white : .gymBroTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            message.isUser
                                ? AnyView(Color.gymBroPrimaryGradient)
                                : AnyView(Color.white)
                        )
                        .clipShape(
                            BubbleShape(isUser: message.isUser)
                        )
                        .shadow(
                            color: Color.black.opacity(0.04),
                            radius: 8,
                            x: 0,
                            y: 2
                        )
                }

                // Embedded workout card
                if let session = message.session {
                    CoachWorkoutCard(
                        session: session,
                        onStartWorkout: onStartWorkout,
                        onRegenerate: onRegenerate
                    )
                }
            }

            if message.isAssistant {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: isUser ? 20 : 4,
            bottomTrailingRadius: isUser ? 4 : 20,
            topTrailingRadius: 20
        )
        .path(in: rect)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        CoachMessageBubble(
            message: CoachMessageResponse(
                id: "1",
                role: "assistant",
                content: "Hey Alex! Ready to crush today's Upper Body session?",
                session: nil,
                createdAt: Date()
            ),
            onStartWorkout: {},
            onRegenerate: {}
        )

        CoachMessageBubble(
            message: CoachMessageResponse(
                id: "2",
                role: "user",
                content: "Build my plan",
                session: nil,
                createdAt: Date()
            ),
            onStartWorkout: {},
            onRegenerate: {}
        )
    }
    .padding(20)
    .background(Color.gymBroBackground)
}
