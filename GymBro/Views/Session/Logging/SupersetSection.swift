//
//  SupersetSection.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

struct SupersetSection: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @ObservedObject var viewModel: SessionFlowViewModel

    /// Snapshot from the parent — used only as identity + fallback. Render
    /// always goes through `liveGroup` so set mutations (complete round,
    /// add round) repaint immediately: this section observes the view
    /// model itself and re-derives the group on every publish, instead of
    /// trusting the parent's captured value to be re-supplied.
    let group: SupersetGroup

    private var liveGroup: SupersetGroup {
        viewModel.supersetGroups.first { $0.id == group.id } ?? group
    }

    @Binding var addSetWeight: String
    @Binding var addSetReps: String
    @Binding var addSetIsBodyweight: Bool
    @Binding var editingSetInfo: (exerciseId: String, setId: String)?
    @Binding var editingRoundIndex: Int?
    @Binding var showAddSetSheet: Bool

    // Superset step-through state — bindings from the parent so the modal
    // (rendered from the parent's sheet) and this section share state.
    @Binding var supersetStepIndex: Int
    @Binding var supersetSetEntries: [(exerciseId: String, weight: Double?, reps: Int, isBodyweight: Bool)]

    @State private var roundOffsets: [Int: CGFloat] = [:]

    // Editing dicts colocated here for the editable round rows.
    @State private var editWeights: [String: String] = [:]
    @State private var editReps: [String: String] = [:]

    private let greenAccent = Color(hex: "30C08D")
    private let purpleAccent = Color(hex: "7A82F6")

    var body: some View {
        let group = liveGroup
        let maxSets = group.exercises.map { $0.sets.count }.max() ?? 0

        return VStack(alignment: .leading, spacing: 16) {
            // Superset badge
            HStack(spacing: 6) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("SUPERSET")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(purpleAccent)
            .clipShape(Capsule())

            // Member cards — same anatomy as the regular exercise screen
            // (image, name, meta) so the superset reads as real exercises,
            // not a text list.
            VStack(spacing: 0) {
                ForEach(Array(group.exercises.enumerated()), id: \.element.id) { idx, ex in
                    memberRow(ex)
                    if idx < group.exercises.count - 1 {
                        Rectangle()
                            .fill(Color.gymBroNeutral100)
                            .frame(height: 1)
                            .padding(.leading, 22)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(purpleAccent.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 8, y: 3)

            // Today header
            HStack(spacing: 4) {
                Text("Today")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                ZStack {
                    Circle().fill(purpleAccent.opacity(0.8)).frame(width: 15, height: 15).blur(radius: 3)
                    Circle().fill(purpleAccent).frame(width: 8, height: 8)
                }
            }

            // Round cards
            ForEach(0..<maxSets, id: \.self) { roundIndex in
                let allCompleted = group.exercises.allSatisfy { ex in
                    roundIndex < ex.sets.count && ex.sets[roundIndex].isCompleted
                }
                if allCompleted {
                    supersetCompletedRound(group: group, roundIndex: roundIndex)
                } else {
                    supersetEditableRound(group: group, roundIndex: roundIndex)
                }
            }

            // Add Round button
            addSetDashedButton {
                editingRoundIndex = nil
                supersetStepIndex = 0
                supersetSetEntries = []
                addSetWeight = ""
                addSetReps = ""
                // Default the first step's toggle from the first exercise's equipment.
                addSetIsBodyweight = group.exercises.first?.equipment == "Bodyweight"
                editingSetInfo = nil
                showAddSetSheet = true
            }
        }
    }

    // MARK: - Member Row

    private func memberRow(_ ex: ActiveSessionExercise) -> some View {
        let completedSets = ex.sets.filter { $0.isCompleted }.count
        let hasTarget = ex.targetSets > 0

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 100)
                .fill(Color(hex: ex.accentColor))
                .frame(width: 5, height: 48)

            memberImage(ex.imageUrl)
                .overlay(alignment: .bottomTrailing) {
                    Text(ex.supersetOrder ?? "")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(purpleAccent)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(ex.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .lineLimit(1)
                    .tracking(-0.3)

                Text([ex.muscleGroup, ex.equipment]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gymBroNeutral400)
                    .lineLimit(1)
            }

            Spacer()

            Text(hasTarget ? "\(completedSets)/\(ex.targetSets)" : "\(completedSets)")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.gymBroNeutral600)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func memberImage(_ imageUrl: String?) -> some View {
        if let imageUrl, let url = URL(string: imageUrl) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                memberImagePlaceholder
            } failure: {
                memberImagePlaceholder
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            memberImagePlaceholder
        }
    }

    private var memberImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(hex: "F5F5F5"))
            .frame(width: 48, height: 48)
            .overlay(
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "D4D4D4"))
            )
    }

    // MARK: - Superset Completed Round

    private func supersetCompletedRound(group: SupersetGroup, roundIndex: Int) -> some View {
        let offset = roundOffsets[roundIndex] ?? 0
        let threshold: CGFloat = 70

        return ZStack {
            // Delete button (swipe left)
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        roundOffsets[roundIndex] = -400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        deleteRound(group: group, roundIndex: roundIndex)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FB2C36"))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: "FB2C36").opacity(0.3), radius: 6, y: 2)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .opacity(min(Double(abs(min(offset, 0)) / threshold), 1.0))
                .padding(.trailing, 12)
            }

            // Repeat button (swipe right)
            HStack {
                Button {
                    repeatRound(group: group, roundIndex: roundIndex)
                    withAnimation(.spring(response: 0.3)) { roundOffsets[roundIndex] = 0 }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F59E0B"))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: "F59E0B").opacity(0.3), radius: 6, y: 2)
                        Image(systemName: "repeat")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .opacity(min(Double(max(offset, 0) / threshold), 1.0))
                .padding(.leading, 12)
                Spacer()
            }

            // Round card content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ROUND \(roundIndex + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(purpleAccent)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(greenAccent)
                }

                ForEach(group.exercises) { ex in
                    if let set = roundIndex < ex.sets.count ? ex.sets[roundIndex] : nil {
                        HStack(spacing: 8) {
                            Text(ex.supersetOrder ?? "")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(purpleAccent)
                                .frame(width: 18)

                            Text(ex.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gymBroNeutral600)
                                .lineLimit(1)

                            Spacer()

                            Text(SetDisplay.line(
                                weight: set.weight,
                                weightUnit: set.weightUnit,
                                reps: set.reps,
                                isBodyweight: set.isBodyweight
                            ))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                        }
                    }
                }
            }
            .padding(14)
            .background(purpleAccent.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(purpleAccent.opacity(0.15), lineWidth: 1)
            )
            .offset(x: offset)
            .contentShape(Rectangle())
            .onTapGesture {
                editRound(group: group, roundIndex: roundIndex)
            }
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        roundOffsets[roundIndex] = value.translation.width * 0.7
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            let cur = roundOffsets[roundIndex] ?? 0
                            if cur < -threshold / 2 {
                                roundOffsets[roundIndex] = -threshold
                            } else if cur > threshold / 2 {
                                roundOffsets[roundIndex] = threshold
                            } else {
                                roundOffsets[roundIndex] = 0
                            }
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Superset Editable Round

    private func supersetEditableRound(group: SupersetGroup, roundIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ROUND \(roundIndex + 1)")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundColor(purpleAccent)

            ForEach(group.exercises) { ex in
                let set: ActiveSet? = roundIndex < ex.sets.count ? ex.sets[roundIndex] : nil

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(ex.supersetOrder ?? "")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(purpleAccent)
                        Text(ex.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        ZStack(alignment: .trailing) {
                            TextField("", text: supersetFieldBinding(
                                dict: $editWeights,
                                set: set,
                                fallbackKey: "\(ex.id)-w-\(roundIndex)",
                                existing: set?.weight.map { $0.formattedWeight }
                            ))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(purpleAccent.opacity(0.3), lineWidth: 1)
                            )

                            let weightKey = set?.id ?? "\(ex.id)-w-\(roundIndex)"
                            if (editWeights[weightKey] ?? set?.weight.map { $0.formattedWeight } ?? "").isEmpty {
                                Text("kg")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gymBroNeutral400)
                                    .padding(.trailing, 10)
                                    .allowsHitTesting(false)
                            }
                        }

                        Text("\u{00D7}")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)

                        TextField("", text: supersetFieldBinding(
                            dict: $editReps,
                            set: set,
                            fallbackKey: "\(ex.id)-r-\(roundIndex)",
                            existing: set?.reps.map { "\($0)" }
                        ))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(purpleAccent.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }

            // Complete Round button
            Button {
                completeRound(group: group, roundIndex: roundIndex)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                    Text("Complete Round")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: [purpleAccent, Color(hex: "6366F1")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: purpleAccent.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(purpleAccent.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    // MARK: - Superset Field Binding

    private func supersetFieldBinding(dict: Binding<[String: String]>, set: ActiveSet?, fallbackKey: String, existing: String?) -> Binding<String> {
        let key = set?.id ?? fallbackKey
        return Binding(
            get: { dict.wrappedValue[key] ?? existing ?? "" },
            set: { dict.wrappedValue[key] = $0 }
        )
    }

    // MARK: - Superset Round Actions

    private func completeRound(group: SupersetGroup, roundIndex: Int) {
        for ex in group.exercises {
            // Members can have FEWER pre-filled sets than the round index
            // (ad-hoc additions, or grouped exercises with different target
            // counts). The editable row still rendered inputs for them via
            // the fallback keys — silently skipping here threw that input
            // away, so the recorded round never appeared on the exercise.
            let set: ActiveSet? = roundIndex < ex.sets.count ? ex.sets[roundIndex] : nil
            let wKey = set?.id ?? "\(ex.id)-w-\(roundIndex)"
            let rKey = set?.id ?? "\(ex.id)-r-\(roundIndex)"
            let wStr = editWeights[wKey] ?? set?.weight.map { $0.formattedWeight } ?? ""
            let rStr = editReps[rKey] ?? set?.reps.map { "\($0)" } ?? ""
            let isBW = set?.isBodyweight ?? (ex.equipment == "Bodyweight")
            let w = isBW ? nil : Double(wStr.replacingOccurrences(of: ",", with: "."))
            let r = Int(rStr) ?? 0
            if let set {
                Task {
                    await viewModel.completeSet(
                        exerciseId: ex.id,
                        setId: set.id,
                        weight: w,
                        reps: r,
                        isBodyweight: isBW
                    )
                }
            } else {
                Task {
                    await viewModel.logSet(
                        exerciseId: ex.id,
                        weight: w,
                        reps: r,
                        isBodyweight: isBW
                    )
                }
            }
        }
        sessionManager.startRestTimer()
    }

    private func deleteRound(group: SupersetGroup, roundIndex: Int) {
        for ex in group.exercises {
            guard roundIndex < ex.sets.count else { continue }
            let setId = ex.sets[roundIndex].id
            Task { await viewModel.deleteSet(exerciseId: ex.id, setId: setId) }
        }
        roundOffsets.removeValue(forKey: roundIndex)
    }

    private func repeatRound(group: SupersetGroup, roundIndex: Int) {
        for ex in group.exercises {
            guard roundIndex < ex.sets.count else { continue }
            let set = ex.sets[roundIndex]
            Task {
                await viewModel.logSet(
                    exerciseId: ex.id,
                    weight: set.isBodyweight ? nil : set.weight,
                    reps: set.reps ?? 0,
                    isBodyweight: set.isBodyweight
                )
            }
        }
    }

    private func editRound(group: SupersetGroup, roundIndex: Int) {
        editingRoundIndex = roundIndex
        editingSetInfo = nil
        supersetStepIndex = 0
        supersetSetEntries = []
        if let firstEx = group.exercises.first, roundIndex < firstEx.sets.count {
            let set = firstEx.sets[roundIndex]
            addSetWeight = set.weight.map { $0.formattedWeight } ?? ""
            addSetReps = set.reps.map { "\($0)" } ?? ""
            addSetIsBodyweight = set.isBodyweight
        } else {
            addSetWeight = ""
            addSetReps = ""
            addSetIsBodyweight = group.exercises.first?.equipment == "Bodyweight"
        }
        showAddSetSheet = true
    }

    // MARK: - Add Set Dashed Button (duplicated inline per refactor plan)

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
}
