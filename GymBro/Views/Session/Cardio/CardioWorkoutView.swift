//
//  CardioWorkoutView.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//
//  Dedicated cardio workout screen — replaces ExerciseLoggingView for
//  any exercise whose muscle_group is "Cardio". Spine owns: session
//  header (reused), image carousel (reused), family eyebrow + title,
//  comparison card slot (placeholder until Slice 3 wires the data),
//  family content slot (Slice 2 fills in F4 Seated Machine for
//  Bicycling), and the pause + Done CTA at the bottom.
//
//  Slice 1 ships this as a minimal-but-correct skeleton: routing fork
//  works, Done writes a cardio set via SessionFlowViewModel.completeSet
//  with the recorded total seconds, and the spine matches the visual
//  language of the design (eyebrow / title / Done CTA). The full F4
//  metric grid + calories ribbon land in Slice 2.

import SwiftUI

struct CardioWorkoutView: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @ObservedObject var viewModel: SessionFlowViewModel

    let exerciseId: String
    var onSwitchToExercise: ((String) -> Void)? = nil
    var onEndWorkout: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    /// Final elapsed captured at Done so the .completed summary view
    /// has a value to display between the Done tap and the bubble-back
    /// through completeSet → exercise.sets.first.durationSeconds. After
    /// the user navigates away, derivedPhase reconstructs .completed
    /// from the persisted set; this @State just bridges the gap.
    @State private var finalElapsedSeconds: Int = 0
    @State private var history: [PreviousSessionEntry] = []

    /// User body weight (kg) for the calorie estimate, loaded from
    /// HealthKit on appear. Nil → the metric view shows "—" instead of
    /// fabricating kcal.
    @State private var bodyWeightKg: Double?

    // Distance-entry sheet (shown after Done; user can type the
    // distance they covered, or skip).
    @State private var showDistanceSheet: Bool = false
    @State private var distanceInputKm: String = ""
    /// Cached duration captured at the moment Done is tapped; persisted
    /// together with the user-entered distance when the sheet is saved.
    @State private var pendingDuration: Int = 0

    // Target editor (duration + pace), opened from the idle TARGET pill.
    @State private var showTargetEditor: Bool = false
    @State private var editDurationMinutes: Int = 30
    @State private var editSpeedKmh: Double = 5.0

    private var exercise: ActiveSessionExercise? {
        viewModel.exercises.first { $0.id == exerciseId }
    }

    private var exerciseIndex: String {
        guard let exercise = exercise else { return "" }
        let idx = viewModel.exercises.firstIndex(where: { $0.id == exercise.id }).map { $0 + 1 } ?? 0
        return "\(idx) OF \(viewModel.exercises.count)"
    }

    private var family: CardioFamily {
        guard let exercise = exercise else { return .treadmill }
        return CardioFamily.detect(
            name: exercise.name,
            equipment: exercise.equipment ?? ""
        )
    }

    /// Per-family metric configuration (MET + completion metrics). The
    /// extensibility seam: drives the calorie math and whether the
    /// finish flow asks for distance.
    private var spec: CardioMetricSpec {
        CardioMetricSpec.spec(for: family, exerciseName: exercise?.name ?? "")
    }

    /// The target pace to display: the coach/user value persisted on the
    /// set when present, otherwise the family heuristic from the spec.
    private var effectiveTargetSpeedKmh: Double? {
        exercise?.sets.first?.targetSpeedKmh ?? spec.targetSpeedKmh
    }

    /// True when a *different* cardio exercise is already recording, so
    /// this one must not offer a Start ("only one cardio at a time").
    private var blockedByOtherCardio: Bool {
        guard let running = sessionManager.runningCardioExerciseId else { return false }
        return running != exerciseId
    }

    /// The duration target, sourced entirely from what the coach/plan
    /// composed — never a hardcoded default. Prefers the set's stored
    /// `durationSeconds`; falls back to the AI's `sets_display` minutes
    /// (parsed into `targetSets`, e.g. "20 min" → 20) so the prescribed
    /// target survives even a pre-duration-field cached session. Zero when
    /// nothing was prescribed (e.g. an ad-hoc-added cardio exercise).
    private var targetSeconds: Int {
        if let dur = exercise?.sets.first?.durationSeconds, dur > 0 { return dur }
        let mins = exercise?.targetSets ?? 0
        return max(0, mins) * 60
    }

    /// True only when the user has paused (active recording where
    /// startDate is nil and isPaused is true). Idle/.completed both
    /// return false. Used by the metric view + the pause button glyph.
    private var isPaused: Bool {
        sessionManager.cardioRecording?.exerciseId == exerciseId
            && sessionManager.cardioRecording?.isPaused == true
    }

    /// Resolves the phase from the available sources, in priority:
    ///   recording (manager state matches this exerciseId)
    /// > completed (the underlying ActiveSet carries a duration)
    /// > idle (default).
    /// This is THE source of truth — no @State phase var. Re-opening
    /// a completed cardio lands on .completed without any onAppear
    /// shenanigans; mid-recording survives leaving the screen because
    /// the manager state is alive across view instances.
    private var derivedPhase: CardioPhase {
        if let rec = sessionManager.cardioRecording, rec.exerciseId == exerciseId {
            return .recording
        }
        if let set = exercise?.sets.first,
           set.isCompleted,
           let dur = set.durationSeconds,
           dur > 0 {
            return .completed
        }
        return .idle
    }

    /// Authoritative "current elapsed" at `now`. Recording reads from
    /// the manager (alive across nav); completed returns the persisted
    /// duration on the set (falling back to `finalElapsedSeconds`,
    /// which only matters between the Done tap and the next render);
    /// idle is 0.
    private func liveElapsed(at now: Date) -> Int {
        switch derivedPhase {
        case .idle:
            return 0
        case .recording:
            return sessionManager.currentCardioElapsed(at: now)
        case .completed:
            if let dur = exercise?.sets.first?.durationSeconds, dur > 0 {
                return dur
            }
            return finalElapsedSeconds
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                SessionHeader(
                    isSuperset: false,
                    exerciseIndex: exerciseIndex,
                    libraryExerciseId: exercise?.libraryExerciseId,
                    onBack: { dismiss() }
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if let exercise = exercise {
                            // Exercise name
                            Text(exercise.name)
                                .font(.system(size: 28, weight: .bold))
                                .tracking(-0.5)
                                .foregroundColor(.gymBroNeutral900)

                            // Image carousel (reused)
                            let imageURLs = ExerciseImageURLBuilder.imageURLs(for: exercise.externalId)
                            if !imageURLs.isEmpty {
                                ExerciseImageCarousel(imageURLs: imageURLs)
                            }

                            // Family eyebrow
                            cardioEyebrow

                            // Recording pill or target — pill needs the
                            // animation tick during recording so the
                            // "RECORDING" dot can pulse later if we add it.
                            phaseStatusPill

                            // Family content slot. Wrapped in a
                            // TimelineView so the metric numbers
                            // recompute on every animation frame while
                            // recording. Idle / completed are static
                            // and reuse the same closure (cheap).
                            // When recording (and not paused), tick every
                            // animation frame; otherwise a single .now is
                            // enough — the metrics don't change.
                            if sessionManager.isCardioActivelyRecording(for: exerciseId) {
                                TimelineView(.animation) { context in
                                    familyContent(elapsed: liveElapsed(at: context.date))
                                }
                            } else {
                                familyContent(elapsed: liveElapsed(at: Date()))
                            }

                            // History — recent cardio sessions for this
                            // exercise. Shown after the family content;
                            // cardio-format (duration · date) instead of
                            // weight × reps. Hidden when nothing logged.
                            if !history.isEmpty {
                                historySection
                            }

                            Spacer(minLength: 120)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
            }
            .background(Color.gymBroBackground.ignoresSafeArea())

            // Bottom slot:
            //   .idle      → UP NEXT peek only (Start lives in the
            //                family widgets area now)
            //   .recording → pause + Done CTA (the only phase with a footer)
            //   .completed → UP NEXT / End Workout peek only — the peek card
            //                already advances, so no redundant "Next" CTA.
            VStack(spacing: 0) {
                if derivedPhase != .recording, let peek = nextExercisePeekCard {
                    peek
                }
                if derivedPhase == .recording {
                    actionsFooter
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { sessionManager.setPhoneActiveExercise(exerciseId) }
        .onDisappear { sessionManager.setPhoneActiveExercise(nil) }
        .task { await loadHistory() }
        .task { await loadBodyWeight() }
        .sheet(isPresented: $showDistanceSheet) {
            distanceEntrySheet
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showTargetEditor) {
            targetEditorSheet
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .analyticsScreen("CardioWorkout")
    }

    // MARK: - Distance entry sheet

    /// Shown after Done so the user can enter the distance they
    /// covered. Save persists durationSeconds + distanceMeters; Skip
    /// persists just durationSeconds (distance stays null in the DB).
    /// Either path finalizes the recording — clears the manager slot,
    /// writes to the view model, and lands the screen on .completed.
    private var distanceEntrySheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("How far did you go?")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(.gymBroNeutral900)
                Text("Duration: \(formatColon(pendingDuration)) · enter distance for pace tracking")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gymBroTextSecondary)
            }
            .padding(.top, 28)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0.0", text: $distanceInputKm)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 44, weight: .heavy))
                    .tracking(-1)
                    .foregroundColor(.gymBroNeutral900)
                    .multilineTextAlignment(.leading)
                    .frame(height: 56)
                    .padding(.horizontal, 16)
                    .background(Color.gymBroNeutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text("km")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.gymBroTextSecondary)
            }

            HStack(spacing: 10) {
                Button {
                    showDistanceSheet = false
                    persistCardioSet(distanceMeters: nil)
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gymBroNeutral100)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    let meters = parseDistanceMeters(distanceInputKm)
                    showDistanceSheet = false
                    persistCardioSet(distanceMeters: meters)
                } label: {
                    Text("Save")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(family.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    /// Final write path after the distance sheet resolves. Clears the
    /// manager slot, hands the set off to the SessionFlowViewModel,
    /// and reloads the history list so the new entry shows up right
    /// away if the user lingers on the screen.
    private func persistCardioSet(distanceMeters: Int?) {
        _ = sessionManager.endCardio()
        finalElapsedSeconds = pendingDuration
        guard let exercise = exercise else { return }
        let duration = pendingDuration
        Task {
            // completeCardioSet updates the existing set or creates one when
            // the exercise has none (ad-hoc cardio) — so the recorded time
            // and distance are never dropped.
            await viewModel.completeCardioSet(
                exerciseId: exercise.id,
                durationSeconds: duration,
                distanceMeters: distanceMeters
            )
            await loadHistory()
        }
    }

    /// Accepts "8", "8.0", "8,2" (EU comma); rejects negatives + non-
    /// numeric junk. Returns meters (Int) or nil when the input is
    /// blank or unparseable.
    private func parseDistanceMeters(_ raw: String) -> Int? {
        let normalized = raw
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty, let km = Double(normalized), km > 0 else {
            return nil
        }
        return Int((km * 1000).rounded())
    }

    // MARK: - Target editor (duration + pace)

    /// Idle pill summary: "30 min · 5.0 km/h" (or just the duration when
    /// the family/exercise has no meaningful pace).
    private var targetSummary: String {
        let m = max(1, targetSeconds / 60)
        let duration = m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m) min"
        if let kmh = effectiveTargetSpeedKmh {
            return "\(duration) · \(formatSpeed(kmh)) km/h"
        }
        return duration
    }

    private func formatSpeed(_ kmh: Double) -> String {
        kmh >= 10 ? String(format: "%.0f", kmh) : String(format: "%.1f", kmh)
    }

    /// Seed the editor from the current targets, then present it.
    private func presentTargetEditor() {
        editDurationMinutes = max(1, targetSeconds / 60)
        editSpeedKmh = effectiveTargetSpeedKmh ?? spec.targetSpeedKmh ?? 5.0
        showTargetEditor = true
    }

    private func saveTargets() {
        guard let exercise = exercise else { return }
        // Only persist a speed for families where it's meaningful.
        let speed = spec.targetSpeedKmh != nil ? editSpeedKmh : nil
        viewModel.updateCardioTargets(
            exerciseId: exercise.id,
            durationSeconds: editDurationMinutes * 60,
            targetSpeedKmh: speed
        )
        showTargetEditor = false
    }

    private var targetEditorSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CARDIO TARGET")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.9)
                    .foregroundColor(family.accent)
                Text("Set your goal")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(.gymBroNeutral900)
            }
            .padding(.top, 6)

            // Duration stepper (5-min increments, 5…120 min).
            targetStepperRow(
                label: "DURATION",
                value: "\(editDurationMinutes) min",
                onMinus: { editDurationMinutes = max(5, editDurationMinutes - 5) },
                onPlus: { editDurationMinutes = min(120, editDurationMinutes + 5) }
            )

            // Pace stepper (0.5 km/h increments) — only when the family
            // tracks a speed (hidden for rowing / climber / interval).
            if spec.targetSpeedKmh != nil {
                targetStepperRow(
                    label: "TARGET SPEED",
                    value: "\(formatSpeed(editSpeedKmh)) km/h",
                    onMinus: { editSpeedKmh = max(1.0, (editSpeedKmh - 0.5)) },
                    onPlus: { editSpeedKmh = min(30.0, (editSpeedKmh + 0.5)) }
                )
            }

            Button(action: saveTargets) {
                Text("Save target")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(family.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func targetStepperRow(
        label: String,
        value: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.gymBroTextSecondary)
                Text(value)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.gymBroNeutral900)
                    .monospacedDigit()
            }
            Spacer()
            HStack(spacing: 10) {
                stepperButton(system: "minus", action: onMinus)
                stepperButton(system: "plus", action: onPlus)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(Color.gymBroNeutral100)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func stepperButton(system: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: system)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.gymBroNeutral900)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gymBroNeutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Eyebrow + status

    private var cardioEyebrow: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(family.accent)
                    .frame(width: 18, height: 18)
                Image(systemName: family.iconSystemName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(family.eyebrow)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.2)
                .foregroundColor(family.accent)
        }
    }

    @ViewBuilder
    private var phaseStatusPill: some View {
        switch derivedPhase {
        case .idle:
            Button {
                presentTargetEditor()
            } label: {
                HStack(spacing: 6) {
                    Text("TARGET")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.9)
                        .foregroundColor(.gymBroTextSecondary)
                    Text(targetSummary)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(family.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.gymBroNeutral100)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        case .recording:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "30C08D"))
                    .frame(width: 7, height: 7)
                Text(family.recordingLabel)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.9)
                    .foregroundColor(Color(hex: "30C08D"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(hex: "30C08D").opacity(0.10))
            .clipShape(Capsule())
        case .completed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "30C08D"))
                Text("COMPLETED")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.9)
                    .foregroundColor(Color(hex: "30C08D"))
            }
        }
    }

    @ViewBuilder
    private func familyContent(elapsed: Int) -> some View {
        // Single-cardio guard: when another cardio is mid-recording, the
        // idle screen shows an "in progress" notice instead of a second
        // Start. Recording/completed states for THIS exercise always
        // render normally.
        if derivedPhase == .idle && blockedByOtherCardio {
            cardioInProgressNotice
        } else {
            CardioMetricsView(
                elapsedSeconds: elapsed,
                phase: derivedPhase,
                isPaused: isPaused,
                targetSeconds: targetSeconds,
                bodyWeightKg: bodyWeightKg,
                accent: family.accent,
                spec: spec,
                targetSpeedKmh: effectiveTargetSpeedKmh,
                distanceMeters: exercise?.sets.first?.distanceMeters,
                onStart: { primaryAction() }
            )
        }
    }

    /// Shown in place of the Start hero when a different cardio exercise
    /// is already being recorded. Tapping it jumps back to the running
    /// exercise so the user can finish it first.
    private var cardioInProgressNotice: some View {
        Button {
            if let running = sessionManager.runningCardioExerciseId {
                onSwitchToExercise?(running)
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "F2812B"))
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(hex: "F2812B").opacity(0.35), radius: 12, y: 6)
                    Image(systemName: "figure.run")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("CARDIO IN PROGRESS")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.9)
                        .foregroundColor(Color(hex: "F2812B"))
                    Text("Finish your current cardio first")
                        .font(.system(size: 16, weight: .heavy))
                        .tracking(-0.3)
                        .foregroundColor(.gymBroNeutral900)
                    Text("Tap to go back to it")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gymBroTextSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymBroNeutral400)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(hex: "F2812B").opacity(0.10), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "F2812B").opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions footer

    /// Rendered only when derivedPhase != .idle. Idle has no bottom
    /// CTA — Start lives inside the family widgets area.
    private var actionsFooter: some View {
        HStack(spacing: 10) {
            // Pause / Resume — only during active recording.
            if derivedPhase == .recording {
                Button {
                    togglePause()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 58, height: 58)
                            .overlay(
                                RoundedRectangle(cornerRadius: 19, style: .continuous)
                                    .stroke(Color.gymBroNeutral100, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gymBroNeutral900)
                    }
                }
                .buttonStyle(.plain)
            }

            Button { primaryAction() } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primaryCTAEyebrow)
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.8)
                            .opacity(0.85)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        // Downscale instead of wrapping to a second line on
                        // narrow devices (e.g. "Start Cardio" on a small phone).
                        Text(primaryCTATitle)
                            .font(.system(size: 17, weight: .heavy))
                            .tracking(-0.3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Spacer()
                    Image(systemName: primaryCTAIcon)
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(family.accent)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .shadow(color: family.accent.opacity(0.32), radius: 10, y: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var primaryCTAEyebrow: String {
        switch derivedPhase {
        case .idle: return "START"
        case .recording: return "LOG & CONTINUE"
        case .completed: return "DONE"
        }
    }

    private var primaryCTATitle: String {
        switch derivedPhase {
        case .idle: return "Start Cardio"
        case .recording: return "Done"
        case .completed: return "Next exercise"
        }
    }

    private var primaryCTAIcon: String {
        switch derivedPhase {
        case .idle: return "play.fill"
        case .recording: return "checkmark"
        case .completed: return "arrow.right"
        }
    }

    // MARK: - Actions

    private func togglePause() {
        guard derivedPhase == .recording else { return }
        if isPaused {
            sessionManager.resumeCardio()
        } else {
            sessionManager.pauseCardio()
        }
    }

    private func primaryAction() {
        switch derivedPhase {
        case .idle:
            sessionManager.startCardio(exerciseId: exerciseId)
            finalElapsedSeconds = 0
        case .recording:
            // Pull the total off the manager but DON'T clear it yet —
            // we still want elapsed shown if the user dismisses the
            // distance sheet without saving. The sheet flow finalizes
            // the recording on Save / Skip via persistCardioSet().
            pendingDuration = sessionManager.currentCardioElapsed(at: Date())
            distanceInputKm = ""
            // Distance-based families (walking, running, cycling, rowing)
            // ask for distance; interval/climber families log time only
            // and finalize straight away.
            if spec.logsDistance {
                showDistanceSheet = true
            } else {
                persistCardioSet(distanceMeters: nil)
            }
        case .completed:
            // Advance via the parent's hand-off if available, otherwise dismiss.
            if let next = viewModel.nextWorkoutTarget(
                afterExerciseId: exerciseId,
                afterSupersetGroupId: nil
            ) {
                switch next {
                case .exercise(let id, _):
                    onSwitchToExercise?(id)
                case .superset:
                    // Cardio doesn't superset; fall through to dismiss.
                    dismiss()
                }
            } else if let onEndWorkout {
                onEndWorkout()
            } else {
                dismiss()
            }
        }
    }

    // MARK: - History section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gymBroNeutral400)
                Text("HISTORY")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.1)
                    .foregroundColor(.gymBroNeutral400)
                Spacer()
            }
            .padding(.top, 12)

            ForEach(history.prefix(5)) { entry in
                let totalSec = entry.sets.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
                let totalMeters = entry.sets.reduce(0) { $0 + ($1.distanceMeters ?? 0) }
                VStack(alignment: .leading, spacing: 8) {
                    Text(formattedSessionDate(entry.sessionDate))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.gymBroNeutral900)
                    HStack(spacing: 18) {
                        historyMetric(label: "DURATION", value: totalSec > 0 ? formatColon(totalSec) : "—")
                        historyMetric(
                            label: "DISTANCE",
                            value: totalMeters > 0 ? formatDistance(totalMeters) : "—"
                        )
                        historyMetric(
                            label: "PACE",
                            value: paceString(seconds: totalSec, meters: totalMeters)
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.gymBroNeutral100, lineWidth: 1)
                )
            }
        }
    }

    private func loadHistory() async {
        guard let libId = exercise?.libraryExerciseId else { return }
        history = await viewModel.loadPreviousSets(for: libId)
    }

    /// Body weight (kg) for the calorie estimate. Prefers a live HealthKit
    /// sample; falls back to the onboarding profile weight when HealthKit
    /// has none (no permission, or the simulator). Stays nil only when
    /// neither source has a value — the metric view then shows "—".
    private func loadBodyWeight() async {
        let healthKit = DependencyContainer.shared.resolve(HealthKitServiceProtocol.self)
        if let sample = try? await healthKit.fetchLatestWeight(), sample.value > 0 {
            bodyWeightKg = sample.value
            return
        }
        if let onboardingWeight = await viewModel.loadBodyWeightKg(), onboardingWeight > 0 {
            bodyWeightKg = onboardingWeight
        }
    }

    private func historyMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.7)
                .foregroundColor(.gymBroTextSecondary)
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.gymBroNeutral900)
                .monospacedDigit()
        }
    }

    private func formatDistance(_ meters: Int) -> String {
        let km = Double(meters) / 1000.0
        return String(format: km >= 10 ? "%.1f km" : "%.2f km", km)
    }

    /// "MM:SS/km" pace. nil → "—".
    private func paceString(seconds: Int, meters: Int) -> String {
        guard seconds > 0, meters > 0 else { return "—" }
        let secPerKm = Double(seconds) / (Double(meters) / 1000.0)
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d/km", m, s)
    }

    private func formattedSessionDate(_ isoDate: String?) -> String {
        guard let isoDate = isoDate else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = iso.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
        guard let d = d else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    // MARK: - Bottom peek (UP NEXT / END WORKOUT)

    /// Quick way to jump to the next exercise without starting cardio.
    /// Same pattern as ExerciseLoggingView's `nextExercisePeekCard`.
    private var nextExercisePeekCard: AnyView? {
        if let target = viewModel.nextWorkoutTarget(
            afterExerciseId: exerciseId,
            afterSupersetGroupId: nil
        ) {
            return AnyView(
                peekCardButton(eyebrow: "UP NEXT", label: target.label, iconName: "arrow.right") {
                    switch target {
                    case .exercise(let id, _): onSwitchToExercise?(id)
                    case .superset: break
                    }
                }
            )
        } else if let onEndWorkout {
            return AnyView(
                peekCardButton(eyebrow: "FINISH", label: "End Workout", iconName: "checkmark") {
                    onEndWorkout()
                }
            )
        }
        return nil
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
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(family.accent.opacity(0.14)).frame(width: 32, height: 32)
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(family.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(eyebrow)
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.9)
                        .foregroundColor(.gymBroNeutral400)
                    Text(label)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.gymBroNeutral900)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymBroNeutral400)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(Color.gymBroNeutral100)
                    .frame(height: 1),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Formatting helpers

    private func formatColon(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func formatHM(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(max(1, m)) min"
    }
}
