//
//  ExerciseLoggingView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import SwiftUI

struct ExerciseLoggingView: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @ObservedObject var viewModel: SessionFlowViewModel

    // Individual mode
    var exerciseId: String? = nil
    // Superset mode
    var supersetGroupId: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var previousSessions: [String: [PreviousSessionEntry]] = [:]
    @State private var exerciseImages: [String: [String]] = [:]
    @State private var showAddSetSheet: Bool = false
    @State private var addSetWeight: String = ""
    @State private var addSetReps: String = ""

    // Edit mode: when non-nil, the modal edits an existing set instead of adding
    @State private var editingSetInfo: (exerciseId: String, setId: String)?

    // Expanded gallery viewer
    @State private var showExpandedGallery: Bool = false
    @State private var expandedGalleryUrls: [URL] = []
    @State private var expandedGalleryIndex: Int = 0

    // Inline editing state for pre-populated sets
    @State private var editWeights: [String: String] = [:]
    @State private var editReps: [String: String] = [:]

    // Superset step-through state
    @State private var supersetStepIndex: Int = 0
    @State private var supersetSetEntries: [(exerciseId: String, weight: Double?, reps: Int)] = []

    private let greenAccent = Color(hex: "30C08D")
    private let purpleAccent = Color(hex: "7A82F6")

    private var isSuperset: Bool { supersetGroupId != nil }

    private var exercise: ActiveSessionExercise? {
        guard let exerciseId = exerciseId else { return nil }
        return viewModel.exercises.first { $0.id == exerciseId }
    }

    private var supersetGroup: SupersetGroup? {
        guard let groupId = supersetGroupId else { return nil }
        return viewModel.supersetGroups.first { $0.id == groupId }
    }

    private var exerciseIndex: String {
        guard let exercise = exercise else { return "" }
        let idx = viewModel.exercises.firstIndex(where: { $0.id == exercise.id }).map { $0 + 1 } ?? 0
        return "\(idx) OF \(viewModel.exercises.count)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                headerSection

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isSuperset, let group = supersetGroup {
                            supersetContent(group)
                        } else if let exercise = exercise {
                            individualContent(exercise)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, sessionManager.isResting ? 120 : 40)
                }
            }
            .background(Color.gymBroBackground.ignoresSafeArea())

            // Floating rest timer bar
            if let remaining = sessionManager.restTimeRemaining {
                restTimerBar(remaining)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: sessionManager.restTimeRemaining)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddSetSheet) {
            editingSetInfo = nil
        } content: {
            addSetModal
                .presentationDetents([.height(isSupersetModal ? 360 : 280)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .task {
            await loadPreviousData()
        }
        .analyticsScreen("ExerciseLogging")
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            // Back button
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .stroke(Color.gymBroNeutral100, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Center: exercise counter + timer
            VStack(spacing: 2) {
                if !isSuperset {
                    Text("EXERCISE \(exerciseIndex)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundColor(.gymBroPrimary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 14))
                        .foregroundColor(.gymBroNeutral600)
                    Text(sessionManager.formattedTime)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(.gymBroNeutral900)
                }
            }

            Spacer()
            // Balance the back button width
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Individual Content

    private func individualContent(_ exercise: ActiveSessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Exercise name
            Text(exercise.name)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.5)
                .foregroundColor(.gymBroNeutral900)

            // Exercise image hint — horizontal carousel
            if let libId = exercise.libraryExerciseId, let images = exerciseImages[libId], !images.isEmpty {
                TabView {
                    ForEach(images, id: \.self) { imgStr in
                        if let imgUrl = URL(string: imgStr) {
                            CachedAsyncImage(url: imgUrl) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        let allUrls = images.compactMap { URL(string: $0) }
                                        expandedGalleryUrls = allUrls
                                        expandedGalleryIndex = allUrls.firstIndex(of: imgUrl) ?? 0
                                        showExpandedGallery = true
                                    }
                            } placeholder: {
                                ShimmerView()
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } failure: {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gymBroNeutral100)
                                    .frame(height: 200)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 32))
                                            .foregroundColor(.gymBroNeutral400)
                                    )
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
                .frame(height: 220)
                .background(
                    ExpandedGalleryView(
                        urls: expandedGalleryUrls,
                        initialIndex: expandedGalleryIndex,
                        isPresented: $showExpandedGallery
                    )
                    .frame(width: 0, height: 0)
                )
            }

            // Live comparison card
            liveComparisonCard(for: exercise)

            // Today's sets card
            todayCard(for: exercise)

            // Previous sessions history
            if let sessions = previousSessions[exercise.id], !sessions.isEmpty {
                previousSessionsSection(sessions)
            }
        }
    }

    // MARK: - Live Comparison Card

    private func liveComparisonCard(for exercise: ActiveSessionExercise) -> some View {
        let prevSets = lastSessionSets(for: exercise.id)
        let currentSets = exercise.sets.filter { $0.isCompleted }

        let totalVolume = currentSets.reduce(0.0) { $0 + (($1.weight ?? 0) * Double($1.reps ?? 0)) }
        let avgWeight = currentSets.isEmpty ? 0.0 : currentSets.reduce(0.0) { $0 + ($1.weight ?? 0) } / Double(currentSets.count)
        let totalReps = currentSets.reduce(0) { $0 + ($1.reps ?? 0) }
        let setCount = currentSets.count

        let hasPrevData = !prevSets.isEmpty
        let prevVolume = prevSets.reduce(0.0) { $0 + (($1.weight ?? 0) * Double($1.reps)) }
        let prevAvgWeight = prevSets.isEmpty ? 0.0 : prevSets.reduce(0.0) { $0 + ($1.weight ?? 0) } / Double(prevSets.count)
        let prevTotalReps = prevSets.reduce(0) { $0 + $1.reps }
        let prevSetCount = prevSets.count

        return VStack(spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gymBroNeutral400)
                Text("LIVE COMPARISON VS LAST SESSION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(.gymBroNeutral400)
                Spacer()
            }

            // Stats grid
            let hasToday = !currentSets.isEmpty
            HStack(spacing: 12) {
                comparisonStat(
                    label: "VOLUME",
                    value: hasToday ? "\(Int(totalVolume))kg" : "--",
                    todayValue: hasToday ? Int(totalVolume) : nil,
                    prevValue: hasPrevData ? Int(prevVolume) : nil
                )
                comparisonStat(
                    label: "AVG WT",
                    value: hasToday ? "\(Int(avgWeight))kg" : "--",
                    todayValue: hasToday ? Int(avgWeight) : nil,
                    prevValue: hasPrevData ? Int(prevAvgWeight) : nil
                )
                comparisonStat(
                    label: "REPS",
                    value: hasToday ? "\(totalReps)" : "--",
                    todayValue: hasToday ? totalReps : nil,
                    prevValue: hasPrevData ? prevTotalReps : nil
                )
                comparisonStat(
                    label: "SETS",
                    value: hasToday ? "\(setCount)" : "--",
                    todayValue: hasToday ? setCount : nil,
                    prevValue: hasPrevData ? prevSetCount : nil
                )
            }
        }
        .padding(16)
        .background(Color.gymBroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 10, y: 2)
        .overlay(alignment: .topTrailing) {
            // Decorative layered icon
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 48))
                .foregroundColor(.gymBroNeutral200.opacity(0.4))
                .padding(.top, -8)
                .padding(.trailing, 8)
        }
    }

    private func comparisonStat(label: String, value: String, todayValue: Int?, prevValue: Int?) -> some View {
        let delta: Int? = {
            guard let today = todayValue, let prev = prevValue else { return nil }
            return today - prev
        }()

        return VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.gymBroNeutral400)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(todayValue != nil ? .gymBroNeutral900 : .gymBroNeutral400)

            if let delta = delta {
                let isUp = delta > 0
                let isDown = delta < 0
                let arrow = isUp ? "arrow.up.right" : (isDown ? "arrow.down.right" : "equal")
                let color: Color = isUp ? Color(hex: "30C08D") : (isDown ? .gymBroPrimary : .gymBroNeutral400)

                HStack(spacing: 2) {
                    Image(systemName: arrow)
                        .font(.system(size: 8, weight: .bold))
                    Text(delta == 0 ? "0" : "\(abs(delta))")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
            } else {
                Text("--")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gymBroNeutral400)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gymBroNeutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Today Card

    /// Returns the best prefill weight/reps for a set: last completed today's set → previous session set → nil
    private func prefillValues(for set: ActiveSet, exercise: ActiveSessionExercise, prevSet: PreviousSet?) -> (weight: Double?, reps: Int?) {
        // First priority: last completed set in today's session (the one right before this set)
        let lastCompleted = exercise.sets
            .filter { $0.isCompleted && $0.setNumber < set.setNumber }
            .last
        if let w = lastCompleted?.weight ?? lastCompleted?.reps.flatMap({ _ in lastCompleted?.weight }),
           let r = lastCompleted?.reps {
            return (w, r)
        }
        if let lc = lastCompleted, (lc.weight != nil || lc.reps != nil) {
            return (lc.weight, lc.reps)
        }
        // Fallback: previous session data
        return (prevSet?.weight, prevSet?.reps)
    }

    @ViewBuilder
    private func setInputRow(exercise: ActiveSessionExercise, set: ActiveSet, prevSet: PreviousSet?) -> some View {
        let prefill = prefillValues(for: set, exercise: exercise, prevSet: prevSet)
        let prefillWeight = prefill.weight
        let prefillReps = prefill.reps
        let prevUnit = prevSet?.weightUnit ?? "kg"

        SwipeableSetRow {
            SetInputRow(
                setNumber: set.setNumber,
                previousWeight: prevSet?.weight,
                previousReps: prevSet?.reps,
                previousWeightUnit: prevUnit,
                weight: weightBinding(for: set, previous: prefillWeight),
                reps: repsBinding(for: set, previous: prefillReps),
                isCompleted: set.isCompleted,
                onComplete: {
                    let wStr: String = editWeights[set.id] ?? set.weight.map { "\(Int($0))" } ?? prefillWeight.map { "\(Int($0))" } ?? ""
                    let rStr: String = editReps[set.id] ?? set.reps.map { "\($0)" } ?? prefillReps.map { "\($0)" } ?? ""
                    let w = Double(wStr)
                    let r = Int(rStr) ?? 0
                    Task {
                        await viewModel.completeSet(
                            exerciseId: exercise.id,
                            setId: set.id,
                            weight: w,
                            reps: r
                        )
                    }
                    sessionManager.startRestTimer()
                },
                onTapCompleted: {
                    editingSetInfo = (exerciseId: exercise.id, setId: set.id)
                    addSetWeight = set.weight.map { "\(Int($0))" } ?? ""
                    addSetReps = set.reps.map { "\($0)" } ?? ""
                    showAddSetSheet = true
                }
            )
        } onDelete: {
            Task {
                await viewModel.deleteSet(exerciseId: exercise.id, setId: set.id)
            }
        } onRepeat: {
            Task {
                await viewModel.logSet(
                    exerciseId: exercise.id,
                    weight: set.weight,
                    reps: set.reps ?? 0
                )
            }
        }
    }

    private func lastSessionSets(for exerciseId: String) -> [PreviousSet] {
        previousSessions[exerciseId]?.first?.sets ?? []
    }

    private func todayCard(for exercise: ActiveSessionExercise) -> some View {
        let lastSets = lastSessionSets(for: exercise.id)

        return VStack(alignment: .leading, spacing: 16) {
            // Header: "Today" with red dot
            HStack(spacing: 4) {
                Text("Today")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                ZStack {
                    Circle()
                        .fill(Color.gymBroPrimary.opacity(0.8))
                        .frame(width: 15, height: 15)
                        .blur(radius: 3)
                    Circle()
                        .fill(Color.gymBroPrimaryDark)
                        .frame(width: 8, height: 8)
                }
            }

            // Set rows
            VStack(spacing: 8) {
                ForEach(exercise.sets) { set in
                    let prevSet = lastSets.first { $0.setNumber == set.setNumber }
                    setInputRow(exercise: exercise, set: set, prevSet: prevSet)
                }
            }

            // Add Set dashed button
            addSetDashedButton {
                editingSetInfo = nil
                // Pre-fill: last completed today's set → previous session set
                let lastCompleted = exercise.sets.filter { $0.isCompleted }.last
                if let lc = lastCompleted, (lc.weight != nil || lc.reps != nil) {
                    addSetWeight = lc.weight.map { "\(Int($0))" } ?? ""
                    addSetReps = lc.reps.map { "\($0)" } ?? ""
                } else {
                    let nextSetNumber = exercise.sets.count + 1
                    let prevSet = lastSets.first { $0.setNumber == nextSetNumber }
                    addSetWeight = prevSet?.weight.map { "\(Int($0))" } ?? ""
                    addSetReps = prevSet.map { "\($0.reps)" } ?? ""
                }
                showAddSetSheet = true
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }

    // MARK: - Previous Sessions Section

    private func previousSessionsSection(_ sessions: [PreviousSessionEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroNeutral400)
                Text("HISTORY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(.gymBroNeutral400)
                Spacer()
            }

            ForEach(sessions) { session in
                VStack(alignment: .leading, spacing: 8) {
                    Text(formattedSessionDate(session.sessionDate))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    ForEach(session.sets) { set in
                        HStack(spacing: 0) {
                            Text("Set \(set.setNumber)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gymBroNeutral400)
                                .frame(width: 48, alignment: .leading)

                            if let w = set.weight {
                                Text("\(Int(w)) \(set.weightUnit)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gymBroNeutral900)
                                Text("  \u{00D7}  ")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gymBroNeutral400)
                            }

                            Text("\(set.reps) reps")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gymBroNeutral900)

                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gymBroNeutral100, lineWidth: 1)
                )
            }
        }
    }

    private func formattedSessionDate(_ isoDate: String?) -> String {
        guard let isoDate = isoDate else { return "Previous Session" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
        guard let date = date else { return isoDate }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Set Bindings

    private func weightBinding(for set: ActiveSet, previous: Double? = nil) -> Binding<String> {
        Binding(
            get: { editWeights[set.id] ?? set.weight.map { "\(Int($0))" } ?? previous.map { "\(Int($0))" } ?? "" },
            set: { editWeights[set.id] = $0 }
        )
    }

    private func repsBinding(for set: ActiveSet, previous: Int? = nil) -> Binding<String> {
        Binding(
            get: { editReps[set.id] ?? set.reps.map { "\($0)" } ?? previous.map { "\($0)" } ?? "" },
            set: { editReps[set.id] = $0 }
        )
    }

    // MARK: - Superset Content

    private func supersetContent(_ group: SupersetGroup) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Exercise labels
            ForEach(group.exercises) { ex in
                HStack(spacing: 8) {
                    Text(ex.supersetOrder ?? "")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(purpleAccent)
                    Text(ex.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                }
            }

            // Rounds
            let maxSets = group.exercises.map { $0.sets.count }.max() ?? 0

            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                ForEach(0..<max(maxSets, 1), id: \.self) { roundIndex in
                    supersetRoundCard(group: group, roundIndex: roundIndex)
                }

                addSetDashedButton {
                    supersetStepIndex = 0
                    supersetSetEntries = []
                    addSetWeight = ""
                    addSetReps = ""
                    showAddSetSheet = true
                }
            }
        }
    }

    // MARK: - Superset Round Card

    private func supersetRoundCard(group: SupersetGroup, roundIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROUND \(roundIndex + 1)")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.gymBroNeutral400)

            ForEach(group.exercises) { ex in
                let set = roundIndex < ex.sets.count ? ex.sets[roundIndex] : nil
                let exLastSets = lastSessionSets(for: ex.id)
                HStack(spacing: 8) {
                    Text(ex.supersetOrder ?? "")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(purpleAccent)
                        .frame(width: 16)

                    let prevSet = exLastSets.first { $0.setNumber == roundIndex + 1 }

                    if let prevWeight = prevSet?.weight {
                        Text("Prev: \(prevWeight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(prevWeight))" : String(format: "%.1f", prevWeight))\(prevSet?.weightUnit ?? "kg") \u{00D7} \(prevSet?.reps ?? 0)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)
                            .frame(width: 90, alignment: .leading)
                    } else {
                        Text("Prev: --")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)
                            .frame(width: 90, alignment: .leading)
                    }

                    Text(set?.weight.map { "\(Int($0))" } ?? "--")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .frame(width: 48, height: 32)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gymBroNeutral200, lineWidth: 1)
                        )

                    Text(set?.reps.map { "\($0)" } ?? "--")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .frame(width: 40, height: 32)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gymBroNeutral200, lineWidth: 1)
                        )

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
    }

    // MARK: - Add Set Dashed Button

    private func addSetDashedButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Add Set")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(Color(hex: "737373"))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundColor(Color.gymBroNeutral200)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Set Modal (Bottom Sheet)

    /// Current superset exercise being entered (nil for individual mode)
    private var currentSupersetExercise: ActiveSessionExercise? {
        guard let group = supersetGroup,
              supersetStepIndex < group.exercises.count else { return nil }
        return group.exercises[supersetStepIndex]
    }

    private var isSupersetModal: Bool {
        supersetGroup != nil
    }

    private var isLastSupersetStep: Bool {
        guard let group = supersetGroup else { return true }
        return supersetStepIndex >= group.exercises.count - 1
    }

    private var addSetModal: some View {
        VStack(spacing: 24) {
            // Title — shows exercise name for superset step-through
            if isSupersetModal, let currentEx = currentSupersetExercise {
                VStack(spacing: 4) {
                    // Step indicator
                    HStack(spacing: 6) {
                        Text("\(currentEx.supersetOrder ?? "")")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(purpleAccent)
                        Text("\(supersetStepIndex + 1) of \(supersetGroup?.exercises.count ?? 0)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)
                    }
                    .padding(.top, 4)

                    Text(currentEx.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                }
            } else {
                Text(editingSetInfo != nil ? "Edit Set" : "Log Set")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .padding(.top, 8)
            }

            // Progress dots for superset
            if isSupersetModal, let group = supersetGroup {
                HStack(spacing: 6) {
                    ForEach(0..<group.exercises.count, id: \.self) { i in
                        Circle()
                            .fill(i <= supersetStepIndex ? purpleAccent : Color.gymBroNeutral200)
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // Input fields
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WEIGHT (kg)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gymBroNeutral400)

                    TextField("0", text: $addSetWeight)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .frame(height: 52)
                        .background(Color.gymBroNeutral100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gymBroNeutral200, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("REPS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gymBroNeutral400)

                    TextField("0", text: $addSetReps)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(height: 52)
                        .background(Color.gymBroNeutral100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gymBroNeutral200, lineWidth: 1)
                        )
                }
            }

            // Action button
            Button {
                submitNewSet()
            } label: {
                HStack(spacing: 8) {
                    if isSupersetModal && !isLastSupersetStep {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                        Text("Next Exercise")
                            .font(.system(size: 17, weight: .bold))
                    } else if editingSetInfo != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Update Set")
                            .font(.system(size: 17, weight: .bold))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Complete Set")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isSupersetModal && !isLastSupersetStep
                    ? LinearGradient(colors: [purpleAccent, Color(hex: "6366F1")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [greenAccent, Color(hex: "28A87A")], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (isSupersetModal && !isLastSupersetStep ? purpleAccent : greenAccent).opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(addSetWeight.isEmpty && addSetReps.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Submit New Set

    private func submitNewSet() {
        let weight = Double(addSetWeight.replacingOccurrences(of: ",", with: "."))
        let reps = Int(addSetReps) ?? 0

        // Edit existing set
        if let editing = editingSetInfo {
            Task {
                await viewModel.updateSet(
                    exerciseId: editing.exerciseId,
                    setId: editing.setId,
                    weight: weight,
                    weightUnit: nil,
                    reps: reps,
                    isCompleted: nil
                )
            }
            showAddSetSheet = false
            editingSetInfo = nil
            return
        }

        if isSupersetModal {
            // Store entry for current exercise
            if let currentEx = currentSupersetExercise {
                supersetSetEntries.append((exerciseId: currentEx.id, weight: weight, reps: reps))
            }

            if isLastSupersetStep {
                // All exercises entered — log all sets and finish
                for entry in supersetSetEntries {
                    Task {
                        await viewModel.logSet(
                            exerciseId: entry.exerciseId,
                            weight: entry.weight,
                            reps: entry.reps
                        )
                    }
                }
                showAddSetSheet = false
                supersetSetEntries = []
                sessionManager.startRestTimer()
            } else {
                // Advance to next exercise
                supersetStepIndex += 1
                addSetWeight = ""
                addSetReps = ""
            }
        } else {
            // Individual exercise
            if let exercise = exercise {
                Task {
                    await viewModel.logSet(
                        exerciseId: exercise.id,
                        weight: weight,
                        reps: reps
                    )
                }
            }
            showAddSetSheet = false
            sessionManager.startRestTimer()
        }
    }

    private func restTimerBar(_ remaining: Int) -> some View {
        let minutes = remaining / 60
        let seconds = remaining % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)

        return HStack {
            // Timer icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("REST TIME")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.8))
                Text(timeString)
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }

            Spacer()

            // +30s button
            Button {
                sessionManager.addRestTime(30)
            } label: {
                Text("+30s")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Skip button
            Button {
                sessionManager.skipRestTimer()
            } label: {
                Text("Skip")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(purpleAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [purpleAccent, Color(hex: "6366F1")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: purpleAccent.opacity(0.4), radius: 16, y: 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Load Previous Data

    private func loadPreviousData() async {
        if let exercise = exercise, let libId = exercise.libraryExerciseId {
            async let sessionsTask = viewModel.loadPreviousSets(for: libId)
            async let imagesTask = fetchExerciseImages(libraryExerciseId: libId)
            let sessions = await sessionsTask
            await imagesTask
            previousSessions[exercise.id] = sessions
        } else if let group = supersetGroup {
            for ex in group.exercises {
                if let libId = ex.libraryExerciseId {
                    async let sessionsTask = viewModel.loadPreviousSets(for: libId)
                    async let imagesTask = fetchExerciseImages(libraryExerciseId: libId)
                    let sessions = await sessionsTask
                    await imagesTask
                    previousSessions[ex.id] = sessions
                }
            }
        }
    }

    private func fetchExerciseImages(libraryExerciseId: String) async {
        let images = await viewModel.fetchExerciseImages(libraryExerciseId: libraryExerciseId)
        if !images.isEmpty {
            exerciseImages[libraryExerciseId] = images
        }
    }
}
