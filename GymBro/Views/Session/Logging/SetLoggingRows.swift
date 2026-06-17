//
//  SetLoggingRows.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

struct SetLoggingRows: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @ObservedObject var viewModel: SessionFlowViewModel

    let exercise: ActiveSessionExercise
    let lastSets: [PreviousSet]

    @Binding var addSetWeight: String
    @Binding var addSetReps: String
    @Binding var addSetIsBodyweight: Bool
    @Binding var editingSetInfo: (exerciseId: String, setId: String)?
    @Binding var showAddSetSheet: Bool

    // Inline editing state for pre-populated sets
    @State private var editWeights: [String: String] = [:]
    @State private var editReps: [String: String] = [:]
    @State private var editBodyweight: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(exercise.sets) { set in
                    let prevSet = lastSets.first { $0.setNumber == set.setNumber }
                    setInputRow(exercise: exercise, set: set, prevSet: prevSet)
                }
            }

            addSetDashedButton {
                editingSetInfo = nil
                let lastCompleted = exercise.sets.filter { $0.isCompleted }.last
                if let lc = lastCompleted, (lc.weight != nil || lc.reps != nil || lc.isBodyweight) {
                    addSetWeight = lc.weight.map { $0.formattedWeight } ?? ""
                    addSetReps = lc.reps.map { "\($0)" } ?? ""
                    addSetIsBodyweight = lc.isBodyweight
                } else {
                    let nextSetNumber = exercise.sets.count + 1
                    let prevSet = lastSets.first { $0.setNumber == nextSetNumber }
                    addSetWeight = prevSet?.weight.map { $0.formattedWeight } ?? ""
                    addSetReps = prevSet.map { "\($0.reps)" } ?? ""
                    addSetIsBodyweight = prevSet?.isBodyweight ?? (exercise.equipment == "Bodyweight")
                }
                showAddSetSheet = true
            }
            .padding(.top, 8)
        }
    }

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
                previousIsBodyweight: prevSet?.isBodyweight ?? false,
                weight: weightBinding(for: set, previous: prefillWeight),
                reps: repsBinding(for: set, previous: prefillReps),
                isBodyweight: bodyweightBinding(for: set, exercise: exercise),
                isCompleted: set.isCompleted,
                onComplete: {
                    // Default BW state mirrors `bodyweightBinding` so the
                    // inline checkmark on a planned BW-equipment set completes
                    // as bodyweight (matches what the row already displays).
                    let defaultBW = set.isBodyweight || exercise.equipment == "Bodyweight"
                    let isBW = editBodyweight[set.id] ?? defaultBW
                    let wStr: String = editWeights[set.id] ?? set.weight.map { $0.formattedWeight } ?? prefillWeight.map { $0.formattedWeight } ?? ""
                    let rStr: String = editReps[set.id] ?? set.reps.map { "\($0)" } ?? prefillReps.map { "\($0)" } ?? ""
                    let w = isBW ? nil : Double(wStr)
                    let r = Int(rStr) ?? 0
                    Task {
                        await viewModel.completeSet(
                            exerciseId: exercise.id,
                            setId: set.id,
                            weight: w,
                            reps: r,
                            isBodyweight: isBW
                        )
                    }
                    sessionManager.startRestTimer()
                },
                onTapCompleted: {
                    // Fires for both planned and completed sets now. Pre-fill
                    // the popup with the existing values, falling back to the
                    // prefill (last completed today → previous session) so the
                    // user isn't starting from blank fields on a planned set.
                    editingSetInfo = (exerciseId: exercise.id, setId: set.id)
                    addSetWeight = (set.weight ?? prefillWeight).map { $0.formattedWeight } ?? ""
                    addSetReps = (set.reps ?? prefillReps).map { "\($0)" } ?? ""
                    // Honor the set's own flag if it was already toggled,
                    // otherwise fall back to the exercise's equipment default
                    // (bodyweight exercises start with BW pre-selected).
                    addSetIsBodyweight = set.isCompleted
                        ? set.isBodyweight
                        : (set.isBodyweight || exercise.equipment == "Bodyweight")
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
                    weight: set.isBodyweight ? nil : set.weight,
                    weightUnit: set.weightUnit,
                    reps: set.reps ?? 0,
                    isBodyweight: set.isBodyweight
                )
                sessionManager.startRestTimer()
            }
        }
    }

    private func bodyweightBinding(for set: ActiveSet, exercise: ActiveSessionExercise) -> Binding<Bool> {
        Binding(
            get: {
                // 1. User-toggled value in this session always wins.
                if let override = editBodyweight[set.id] { return override }
                // 2. Persisted on the set itself (re-edit of a completed bodyweight set).
                if set.isBodyweight { return true }
                // 3. New row on a Bodyweight-equipment exercise defaults ON.
                return !set.isCompleted && exercise.equipment == "Bodyweight"
            },
            set: { newValue in
                editBodyweight[set.id] = newValue
                if newValue { editWeights[set.id] = "" }
            }
        )
    }

    private func weightBinding(for set: ActiveSet, previous: Double? = nil) -> Binding<String> {
        Binding(
            get: { editWeights[set.id] ?? set.weight.map { $0.formattedWeight } ?? previous.map { $0.formattedWeight } ?? "" },
            set: { editWeights[set.id] = $0 }
        )
    }

    private func repsBinding(for set: ActiveSet, previous: Int? = nil) -> Binding<String> {
        Binding(
            get: { editReps[set.id] ?? set.reps.map { "\($0)" } ?? previous.map { "\($0)" } ?? "" },
            set: { editReps[set.id] = $0 }
        )
    }

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
