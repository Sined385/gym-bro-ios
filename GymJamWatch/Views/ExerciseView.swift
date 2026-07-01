//
//  ExerciseView.swift
//  GymJamWatch
//
//  Displays current exercise with tap-to-complete sets.
//

import SwiftUI

struct ExerciseView: View {

    @EnvironmentObject var sessionViewModel: WatchSessionViewModel
    @EnvironmentObject var setLoggingViewModel: WatchSetLoggingViewModel

    @State private var showSetInput = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Session header with elapsed time, HR, and set progress
                HStack {
                    Text(sessionViewModel.elapsedTime)
                        .font(WatchTypography.numeric)
                        .foregroundColor(.white)
                        .monospacedDigit()

                    Spacer()

                    if sessionViewModel.currentHeartRate > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.red)
                            Text("\(Int(sessionViewModel.currentHeartRate))")
                                .font(WatchTypography.caption)
                                .foregroundColor(.red)
                                .monospacedDigit()
                        }

                        Spacer()
                    }

                    Text("\(sessionViewModel.totalSetsCompleted)/\(sessionViewModel.totalSets)")
                        .font(WatchTypography.caption)
                        .foregroundColor(WatchColors.textSecondary)
                }
                .padding(.horizontal, 8)

                if let exercise = sessionViewModel.currentExercise {
                    if exercise.isCardioExercise {
                        // Cardio (walking/running/etc.) is time-based — show a
                        // Start → live timer → Done flow, not set rows.
                        CardioExerciseCard(exercise: exercise)
                    } else {
                    ExerciseCard(exercise: exercise) { set in
                        setLoggingViewModel.loadFromSet(set)
                        showSetInput = true
                    }

                    // Repeat Last button — one-tap completion with previous
                    // set's weight/reps. Visible whenever we have a value
                    // to repeat; works for both planned exercises (where a
                    // pending template set is waiting in `currentSet`) and
                    // manually-added mid-session exercises (no template —
                    // we append as a new set instead).
                    if let lastReps = setLoggingViewModel.lastCompletedReps ?? sessionViewModel.lastCompletedReps {
                        Button {
                            let lastWeight = setLoggingViewModel.lastCompletedWeight ?? sessionViewModel.lastCompletedWeight
                            setLoggingViewModel.loadForRepeat(weight: lastWeight, reps: lastReps)
                            if let currentSet = exercise.currentSet {
                                setLoggingViewModel.completeSet(exerciseId: exercise.id, setId: currentSet.id)
                            } else {
                                setLoggingViewModel.logSet(exerciseId: exercise.id, weight: lastWeight, reps: lastReps)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12))
                                Text("Repeat Last")
                                    .font(WatchTypography.caption)
                            }
                        }
                        .buttonStyle(WatchOutlineButtonStyle())
                    }
                    }
                } else if sessionViewModel.exercises.isEmpty {
                    Text("Waiting for exercises...")
                        .font(WatchTypography.caption)
                        .foregroundColor(WatchColors.textSecondary)
                        .padding(.top, 20)
                } else {
                    // All exercises complete
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(WatchColors.green)
                        Text("All sets done!")
                            .font(WatchTypography.body)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.horizontal, 8)
        }
        .sheet(isPresented: $showSetInput) {
            if let exercise = sessionViewModel.currentExercise,
               let currentSet = exercise.currentSet {
                SetInputView(
                    exerciseId: exercise.id,
                    setId: currentSet.id,
                    exerciseName: exercise.name
                )
            }
        }
    }
}

// MARK: - Exercise Card

struct ExerciseCard: View {
    let exercise: WatchExerciseState
    let onTapSet: (WatchSetState) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Exercise info with accent bar
            HStack(spacing: 8) {
                Rectangle()
                    .fill(WatchColors.primary)
                    .frame(width: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(WatchTypography.sectionTitle)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(exercise.muscleGroup)
                        .font(WatchTypography.caption)
                        .foregroundColor(WatchColors.textSecondary)
                }
            }

            // Set progress dots
            HStack(spacing: 4) {
                ForEach(exercise.sets) { set in
                    Circle()
                        .fill(set.isCompleted ? WatchColors.green : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
                Spacer()
                Text("Set \(exercise.completedSetsCount + 1) of \(exercise.sets.count)")
                    .font(WatchTypography.caption)
                    .foregroundColor(WatchColors.textSecondary)
            }

            // Sets list
            ForEach(exercise.sets) { set in
                SetRow(set: set, isCurrent: !set.isCompleted && set.id == exercise.currentSet?.id) {
                    onTapSet(set)
                }
            }
        }
        .padding(10)
        .background(WatchColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Set Row

struct SetRow: View {
    let set: WatchSetState
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                // Accent bar for current set
                if isCurrent {
                    Rectangle()
                        .fill(WatchColors.primary)
                        .frame(width: 2, height: 28)
                }

                Text(setDisplay)
                    .font(WatchTypography.body)
                    .foregroundColor(set.isCompleted ? WatchColors.textSecondary : .white)
                    .monospacedDigit()

                Spacer()

                if set.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(WatchColors.green)
                } else if isCurrent {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundColor(WatchColors.primary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(isCurrent ? WatchColors.primary.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(set.isCompleted)
    }

    private var setDisplay: String {
        let w = set.weight.map { w -> String in
            if w == 0 { return "BW" }
            return w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
        } ?? "—"
        let r = set.reps.map { "\($0)" } ?? "—"
        let unit = set.weight != nil && set.weight != 0 ? set.weightUnit : ""
        return "\(w)\(unit) × \(r)"
    }
}

// MARK: - Cardio Exercise Card

/// Time-based cardio on the Watch: Start → live timer (+ HR) → Done, mirroring
/// the phone's idle/recording cardio states. On Done the recorded duration is
/// sent to the phone, which completes the cardio set (distance left empty).
struct CardioExerciseCard: View {
    @EnvironmentObject var sessionViewModel: WatchSessionViewModel
    @EnvironmentObject var setLoggingViewModel: WatchSetLoggingViewModel

    let exercise: WatchExerciseState

    private enum Phase { case idle, recording, completed }

    /// Phase is derived from the SYNCED phone state — never local — so a walk
    /// started/stopped/restarted on the phone is reflected here, and vice
    /// versa (the Watch's Start/Done just drive the phone's clock).
    private var phase: Phase {
        if sessionViewModel.sessionState?.isRecordingCardio(exercise.id) == true {
            return .recording
        }
        if let set = exercise.sets.first, set.isCompleted,
           let dur = set.durationSeconds, dur > 0 {
            return .completed
        }
        return .idle
    }

    private var completedDuration: Int {
        exercise.sets.first?.durationSeconds ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(WatchColors.primary)
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(WatchTypography.sectionTitle)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text(exercise.muscleGroup)
                        .font(WatchTypography.caption)
                        .foregroundColor(WatchColors.textSecondary)
                }
            }

            switch phase {
            case .recording:
                // Live elapsed driven by the synced recording start; matches
                // the phone tick-for-tick without per-second messages.
                TimelineView(.periodic(from: Date(), by: 1)) { context in
                    let elapsed = sessionViewModel.sessionState?.cardioElapsed(at: context.date) ?? 0
                    Text(Self.formatElapsed(elapsed))
                        .font(.system(size: 34, weight: .bold).monospacedDigit())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    let elapsed = sessionViewModel.sessionState?.cardioElapsed(at: Date()) ?? 0
                    setLoggingViewModel.completeCardio(exerciseId: exercise.id, durationSeconds: elapsed)
                } label: {
                    Text("Done")
                        .font(WatchTypography.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WatchPrimaryButtonStyle())

            case .completed:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(WatchColors.green)
                    Text(Self.formatElapsed(completedDuration))
                        .font(.system(size: 22, weight: .bold).monospacedDigit())
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)

            case .idle:
                Button {
                    setLoggingViewModel.startCardio(exerciseId: exercise.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                        Text("Start")
                            .font(WatchTypography.body)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WatchPrimaryButtonStyle())
            }
        }
        .padding(10)
        .background(WatchColors.cardBackground)
        .cornerRadius(12)
    }

    private static func formatElapsed(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
