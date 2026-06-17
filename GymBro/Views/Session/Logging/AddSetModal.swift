//
//  AddSetModal.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

struct AddSetModal: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @ObservedObject var viewModel: SessionFlowViewModel

    // Individual mode exercise (nil in superset mode)
    let exercise: ActiveSessionExercise?
    // Superset mode group (nil in individual mode)
    let supersetGroup: SupersetGroup?

    @Binding var addSetWeight: String
    @Binding var addSetReps: String
    @Binding var addSetIsBodyweight: Bool
    @Binding var editingSetInfo: (exerciseId: String, setId: String)?
    @Binding var editingRoundIndex: Int?
    @Binding var showAddSetSheet: Bool
    @Binding var supersetStepIndex: Int
    @Binding var supersetSetEntries: [(exerciseId: String, weight: Double?, reps: Int, isBodyweight: Bool)]

    private let greenAccent = Color(hex: "30C08D")
    private let purpleAccent = Color(hex: "7A82F6")

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

    var body: some View {
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
                    .padding(.top, 28)

                    Text(currentEx.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                }
            } else {
                Text(editingSetInfo != nil ? "Edit Set" : (editingRoundIndex != nil ? "Edit Round" : "Log Set"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .padding(.top, 28)
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

                    if addSetIsBodyweight {
                        Text("BW")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.gymBroPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.gymBroPrimary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gymBroPrimary.opacity(0.3), lineWidth: 1)
                            )
                    } else {
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
                            .simultaneousGesture(TapGesture().onEnded { addSetWeight = "" })
                    }
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
                        .simultaneousGesture(TapGesture().onEnded { addSetReps = "" })
                }
            }

            // Bodyweight checkbox — lives below the inputs so it reads as a
            // modifier on the weight field rather than a separate concept.
            Button {
                addSetIsBodyweight.toggle()
                if addSetIsBodyweight { addSetWeight = "" }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: addSetIsBodyweight ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(addSetIsBodyweight ? .gymBroPrimary : .gymBroNeutral400)
                    Text("Use bodyweight")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
            .disabled(!addSetIsBodyweight && addSetWeight.isEmpty && addSetReps.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Submit New Set

    private func submitNewSet() {
        let isBW = addSetIsBodyweight
        let weight: Double? = isBW ? nil : Double(addSetWeight.replacingOccurrences(of: ",", with: "."))
        let reps = Int(addSetReps) ?? 0

        // Edit existing set — if the set was still planned (not yet completed),
        // saving the popup also marks it done. Editing a completed set just
        // updates values in place without flipping any state.
        if let editing = editingSetInfo {
            let wasCompleted = viewModel.exercises
                .first(where: { $0.id == editing.exerciseId })?
                .sets.first(where: { $0.id == editing.setId })?
                .isCompleted ?? false
            Task {
                if wasCompleted {
                    await viewModel.updateSet(
                        exerciseId: editing.exerciseId,
                        setId: editing.setId,
                        weight: weight,
                        weightUnit: nil,
                        reps: reps,
                        isCompleted: nil,
                        isBodyweight: isBW
                    )
                } else {
                    await viewModel.completeSet(
                        exerciseId: editing.exerciseId,
                        setId: editing.setId,
                        weight: weight,
                        reps: reps,
                        isBodyweight: isBW
                    )
                    sessionManager.startRestTimer()
                }
            }
            showAddSetSheet = false
            editingSetInfo = nil
            return
        }

        if isSupersetModal {
            // Store entry for current exercise
            if let currentEx = currentSupersetExercise {
                supersetSetEntries.append((exerciseId: currentEx.id, weight: weight, reps: reps, isBodyweight: isBW))
            }

            if isLastSupersetStep {
                if let editingRound = editingRoundIndex {
                    // Update existing round
                    for entry in supersetSetEntries {
                        if let group = supersetGroup,
                           let ex = group.exercises.first(where: { $0.id == entry.exerciseId }),
                           editingRound < ex.sets.count {
                            Task {
                                await viewModel.updateSet(
                                    exerciseId: entry.exerciseId,
                                    setId: ex.sets[editingRound].id,
                                    weight: entry.weight,
                                    weightUnit: nil,
                                    reps: entry.reps,
                                    isCompleted: nil,
                                    isBodyweight: entry.isBodyweight
                                )
                            }
                        }
                    }
                    editingRoundIndex = nil
                } else {
                    // Add new round — log new sets
                    for entry in supersetSetEntries {
                        Task {
                            await viewModel.logSet(
                                exerciseId: entry.exerciseId,
                                weight: entry.weight,
                                reps: entry.reps,
                                isBodyweight: entry.isBodyweight
                            )
                        }
                    }
                }
                showAddSetSheet = false
                supersetSetEntries = []
                sessionManager.startRestTimer()
            } else {
                // Advance to next exercise
                supersetStepIndex += 1
                // Pre-fill with existing data when editing a round; otherwise
                // default the bodyweight toggle from the next exercise's equipment.
                if let editingRound = editingRoundIndex,
                   let group = supersetGroup,
                   supersetStepIndex < group.exercises.count {
                    let nextEx = group.exercises[supersetStepIndex]
                    if editingRound < nextEx.sets.count {
                        let nextSet = nextEx.sets[editingRound]
                        addSetWeight = nextSet.weight.map { $0.formattedWeight } ?? ""
                        addSetReps = nextSet.reps.map { "\($0)" } ?? ""
                        addSetIsBodyweight = nextSet.isBodyweight
                    } else {
                        addSetWeight = ""
                        addSetReps = ""
                        addSetIsBodyweight = nextEx.equipment == "Bodyweight"
                    }
                } else if let group = supersetGroup, supersetStepIndex < group.exercises.count {
                    let nextEx = group.exercises[supersetStepIndex]
                    addSetWeight = ""
                    addSetReps = ""
                    addSetIsBodyweight = nextEx.equipment == "Bodyweight"
                } else {
                    addSetWeight = ""
                    addSetReps = ""
                }
            }
        } else {
            // Individual exercise
            if let exercise = exercise {
                Task {
                    await viewModel.logSet(
                        exerciseId: exercise.id,
                        weight: weight,
                        reps: reps,
                        isBodyweight: isBW
                    )
                }
            }
            showAddSetSheet = false
            sessionManager.startRestTimer()
        }
    }
}
