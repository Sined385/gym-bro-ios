//
//  SetInputView.swift
//  GymJamWatch
//
//  Digital Crown weight input and +/- reps for set logging.
//

import SwiftUI

struct SetInputView: View {

    let exerciseId: String
    let setId: String
    let exerciseName: String

    @EnvironmentObject var setLoggingViewModel: WatchSetLoggingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Exercise name
                Text(exerciseName)
                    .font(WatchTypography.sectionTitle)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Weight input
                VStack(spacing: 4) {
                    Text("WEIGHT")
                        .font(WatchTypography.micro)
                        .foregroundColor(WatchColors.textSecondary)

                    HStack {
                        Button {
                            setLoggingViewModel.decrementWeight()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(WatchColors.textSecondary)
                        }
                        .buttonStyle(.plain)

                        Text(setLoggingViewModel.weightDisplay)
                            .font(WatchTypography.numeric)
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .frame(minWidth: 50)

                        Text("kg")
                            .font(WatchTypography.caption)
                            .foregroundColor(WatchColors.textSecondary)

                        Button {
                            setLoggingViewModel.incrementWeight()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(WatchColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .focusable()
                .digitalCrownRotation(
                    $setLoggingViewModel.weight,
                    from: 0,
                    through: 500,
                    by: 2.5,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

                // Reps input
                VStack(spacing: 4) {
                    Text("REPS")
                        .font(WatchTypography.micro)
                        .foregroundColor(WatchColors.textSecondary)

                    HStack {
                        Button {
                            setLoggingViewModel.decrementReps()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(WatchColors.textSecondary)
                        }
                        .buttonStyle(.plain)

                        Text("\(setLoggingViewModel.reps)")
                            .font(WatchTypography.numeric)
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .frame(minWidth: 40)

                        Button {
                            setLoggingViewModel.incrementReps()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(WatchColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Complete button
                Button {
                    setLoggingViewModel.completeSet(exerciseId: exerciseId, setId: setId)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Complete Set")
                    }
                }
                .buttonStyle(WatchPrimaryButtonStyle())
                .padding(.top, 4)
            }
            .padding(.horizontal, 8)
        }
    }
}
