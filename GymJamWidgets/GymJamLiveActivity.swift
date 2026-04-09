//
//  GymJamLiveActivity.swift
//  GymJamWidgets
//
//  Created by Claude Code on 2026-04-07.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct GymJamLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .font(.caption2)
                            .foregroundStyle(WidgetColors.primary)
                        Text(context.attributes.sessionStartDate, style: .timer)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isResting, let restEnd = context.state.restEndDate {
                        HStack(spacing: 4) {
                            Image(systemName: "stopwatch.fill")
                                .font(.caption2)
                                .foregroundStyle(WidgetColors.purple)
                            Text(restEnd, style: .timer)
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(WidgetColors.purple)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Text("\(context.state.totalSetsCompleted)")
                                .font(.caption2.bold())
                                .foregroundStyle(WidgetColors.green)
                            Text("sets")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if let exerciseName = context.state.lastExerciseName {
                        HStack {
                            Text(exerciseName)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if let setDisplay = context.state.lastSetDisplay {
                                Text(setDisplay)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isResting ? "stopwatch.fill" : "dumbbell.fill")
                    .foregroundStyle(context.state.isResting ? WidgetColors.purple : WidgetColors.primary)
            } compactTrailing: {
                if context.state.isResting, let restEnd = context.state.restEndDate {
                    Text(timerInterval: Date.now...restEnd, countsDown: true)
                        .multilineTextAlignment(.center)
                        .frame(width: 36)
                        .font(.caption2.bold())
                        .foregroundStyle(WidgetColors.purple)
                } else {
                    Text("\(context.state.totalSetsCompleted) sets")
                        .font(.caption2)
                        .foregroundStyle(WidgetColors.primary)
                }
            } minimal: {
                Image(systemName: context.state.isResting ? "stopwatch.fill" : "dumbbell.fill")
                    .foregroundStyle(context.state.isResting ? WidgetColors.purple : WidgetColors.primary)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(spacing: 8) {
            // Header row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.subheadline)
                        .foregroundStyle(WidgetColors.primary)
                    Text(context.attributes.sessionTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(context.attributes.sessionStartDate, style: .timer)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Rest timer banner
            if context.state.isResting, let restEnd = context.state.restEndDate {
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch.fill")
                        .font(.caption)
                        .foregroundStyle(WidgetColors.purple)
                    Text("Rest:")
                        .font(.caption.bold())
                        .foregroundStyle(WidgetColors.purple)
                    Text(restEnd, style: .timer)
                        .font(.caption.bold())
                        .monospacedDigit()
                        .foregroundStyle(WidgetColors.purple)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(WidgetColors.purple.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Exercise info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let exerciseName = context.state.lastExerciseName {
                        Text(exerciseName)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        if let setDisplay = context.state.lastSetDisplay {
                            Text("Last: \(setDisplay)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(context.state.totalSetsCompleted) sets completed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Action buttons
            HStack(spacing: 8) {
                if context.state.isResting {
                    Link(destination: URL(string: "gymjam://skip-rest")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                                .font(.caption2)
                            Text("Skip Rest")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(WidgetColors.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(WidgetColors.purple.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                if context.state.lastSetDisplay != nil {
                    Link(destination: URL(string: "gymjam://repeat-last-set")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                            Text("Repeat Set")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(WidgetColors.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(WidgetColors.green.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.85))
    }
}
