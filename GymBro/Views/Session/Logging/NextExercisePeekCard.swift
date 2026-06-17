//
//  NextExercisePeekCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

/// Bottom-anchored mini card that "peeks" up from the screen edge,
/// styled like an Apple Music mini-player. Drag handle at top, "UP
/// NEXT" label + exercise name in the body, chevron on the trailing
/// edge. Tap to jump to that exercise — or, when this is the last
/// exercise in the workout, the same slot becomes an "End Workout" CTA.
struct NextExercisePeekCard: View {
    @ObservedObject var viewModel: SessionFlowViewModel
    let exerciseId: String?
    let supersetGroupId: String?
    var onSwitchToExercise: ((String) -> Void)? = nil
    var onSwitchToSuperset: ((String) -> Void)? = nil
    var onEndWorkout: (() -> Void)? = nil

    @ViewBuilder
    var body: some View {
        if let target = viewModel.nextWorkoutTarget(
            afterExerciseId: exerciseId,
            afterSupersetGroupId: supersetGroupId
        ) {
            peekCardButton(eyebrow: "UP NEXT", label: target.label, iconName: "arrow.right") {
                switch target {
                case .exercise(let id, _):
                    onSwitchToExercise?(id)
                case .superset(let groupId, _):
                    onSwitchToSuperset?(groupId)
                }
            }
        } else if let onEndWorkout {
            peekCardButton(eyebrow: "FINISH", label: "End Workout", iconName: "checkmark") {
                onEndWorkout()
            }
        }
    }

    private func peekCardButton(
        eyebrow: String,
        label: String,
        iconName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Small accent badge
                    ZStack {
                        Circle()
                            .fill(Color.gymBroPrimary.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: iconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gymBroPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(eyebrow)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.9)
                            .foregroundColor(.gymBroNeutral400)
                        Text(label)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.gymBroNeutral900)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gymBroNeutral400)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
                .ignoresSafeArea(edges: .bottom)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: -4)
        }
        .buttonStyle(.plain)
    }
}
