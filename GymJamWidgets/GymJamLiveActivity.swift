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
            // Lock Screen / Banner UI. .widgetURL gives the Live Activity a
            // tap target — on watchOS this opens the GymJam Watch app
            // straight into the active workout view (which is what users
            // expect when they tap the Smart Stack tile on their wrist).
            lockScreenView(context: context)
                .widgetURL(URL(string: "gymjam://workout"))
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
                    } else if context.state.isCardioActive {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.run")
                                .font(.caption2)
                                .foregroundStyle(WidgetColors.green)
                            cardioTimerText(context.state)
                                .font(.caption2.bold())
                                .monospacedDigit()
                                .foregroundStyle(WidgetColors.green)
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
                    if let cardioName = context.state.cardioExerciseName {
                        HStack {
                            Text(cardioName)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if context.state.cardioPausedElapsedSeconds != nil {
                                Text("Paused")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if let exerciseName = context.state.lastExerciseName {
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
                Image(systemName: compactIconName(context.state))
                    .foregroundStyle(compactIconColor(context.state))
            } compactTrailing: {
                if context.state.isResting, let restEnd = context.state.restEndDate {
                    Text(timerInterval: Date.now...restEnd, countsDown: true)
                        .multilineTextAlignment(.center)
                        .frame(width: 36)
                        .font(.caption2.bold())
                        .foregroundStyle(WidgetColors.purple)
                } else if context.state.isCardioActive {
                    cardioTimerText(context.state)
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .foregroundStyle(WidgetColors.green)
                } else {
                    Text("\(context.state.totalSetsCompleted) sets")
                        .font(.caption2)
                        .foregroundStyle(WidgetColors.primary)
                }
            } minimal: {
                Image(systemName: compactIconName(context.state))
                    .foregroundStyle(compactIconColor(context.state))
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

            // Cardio banner — a walking/rowing recording has no sets to
            // report; show the exercise + a live elapsed timer instead of
            // an empty card.
            if context.state.isCardioActive {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.caption)
                        .foregroundStyle(WidgetColors.green)
                    Text(context.state.cardioExerciseName ?? "Cardio")
                        .font(.caption.bold())
                        .foregroundStyle(WidgetColors.green)
                        .lineLimit(1)
                    Spacer()
                    if context.state.cardioPausedElapsedSeconds != nil {
                        Text("Paused")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    cardioTimerText(context.state)
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(WidgetColors.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(WidgetColors.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
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
            }

            // Action buttons — hidden during cardio (repeating a set or
            // skipping rest makes no sense mid-walk).
            if !context.state.isCardioActive {
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
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.85))
    }

    // MARK: - Cardio helpers

    /// Live elapsed for the running cardio: anchored `.timer` text while
    /// recording (ticks with zero pushes), frozen mm:ss while paused.
    @ViewBuilder
    private func cardioTimerText(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        if let anchor = state.cardioAnchorDate {
            Text(anchor, style: .timer)
        } else if let paused = state.cardioPausedElapsedSeconds {
            Text(Self.formatElapsed(paused))
        }
    }

    private static func formatElapsed(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func compactIconName(_ state: WorkoutActivityAttributes.ContentState) -> String {
        if state.isResting { return "stopwatch.fill" }
        if state.isCardioActive { return "figure.run" }
        return "dumbbell.fill"
    }

    private func compactIconColor(_ state: WorkoutActivityAttributes.ContentState) -> Color {
        if state.isResting { return WidgetColors.purple }
        if state.isCardioActive { return WidgetColors.green }
        return WidgetColors.primary
    }
}
