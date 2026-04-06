//
//  PlanTimelineIndicator.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-18.
//

import SwiftUI

enum PlanDayState {
    case completed
    case upNext
    case future
    case rest
    case skipped
}

struct PlanTimelineIndicator: View {

    let state: PlanDayState
    let isLast: Bool

    private let completedColor = Color(hex: "30C08D")
    private let upNextColor = Color(hex: "E86A75")
    private let futureColor = Color(hex: "D4D4D4")

    var body: some View {
        VStack(spacing: 0) {
            // Status circle
            ZStack {
                switch state {
                case .completed:
                    Circle()
                        .fill(completedColor)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)

                case .upNext:
                    // Glow effect
                    Circle()
                        .fill(upNextColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Circle()
                        .fill(upNextColor)
                        .frame(width: 20, height: 20)

                case .future:
                    Circle()
                        .stroke(futureColor, lineWidth: 2)
                        .frame(width: 20, height: 20)

                case .rest:
                    Circle()
                        .stroke(futureColor, lineWidth: 2)
                        .frame(width: 20, height: 20)

                case .skipped:
                    Circle()
                        .fill(futureColor)
                        .frame(width: 24, height: 24)
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 32, height: 32)

            // Vertical line
            if !isLast {
                Rectangle()
                    .fill(state == .completed ? completedColor.opacity(0.3) : futureColor.opacity(0.5))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        PlanTimelineIndicator(state: .completed, isLast: false)
            .frame(height: 100)
        PlanTimelineIndicator(state: .upNext, isLast: false)
            .frame(height: 100)
        PlanTimelineIndicator(state: .future, isLast: false)
            .frame(height: 100)
        PlanTimelineIndicator(state: .skipped, isLast: false)
            .frame(height: 100)
        PlanTimelineIndicator(state: .rest, isLast: true)
            .frame(height: 100)
    }
    .padding()
}
