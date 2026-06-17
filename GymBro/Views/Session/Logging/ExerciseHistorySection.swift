//
//  ExerciseHistorySection.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

struct ExerciseHistorySection: View {
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @ObservedObject var viewModel: SessionFlowViewModel

    let sessions: [PreviousSessionEntry]
    let exercise: ActiveSessionExercise
    let readOnly: Bool

    @Binding var addSetWeight: String
    @Binding var addSetReps: String
    @Binding var addSetIsBodyweight: Bool
    @Binding var editingSetInfo: (exerciseId: String, setId: String)?
    @Binding var editingRoundIndex: Int?
    @Binding var showAddSetSheet: Bool

    var body: some View {
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

                    ForEach(Array(session.sets.enumerated()), id: \.element.id) { idx, set in
                        previousSetRow(set, exercise: exercise)
                        if idx < session.sets.count - 1 {
                            Divider().background(Color.gymBroNeutral100)
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

    /// Single row in the history list. Two affordances on the right:
    /// pencil = open the Log Set modal pre-filled with this set's values
    /// so the user can tweak before logging; yellow repeat = log it now
    /// as-is. Repeat button matches the swipe-right repeat on current sets
    /// so the action reads as the same gesture, different surface.
    private func previousSetRow(_ set: PreviousSet, exercise: ActiveSessionExercise) -> some View {
        HStack(spacing: 12) {
            Text("Set \(set.setNumber)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
                .frame(width: 48, alignment: .leading)

            Text(SetDisplay.line(
                weight: set.weight,
                weightUnit: set.weightUnit,
                reps: set.reps,
                isBodyweight: set.isBodyweight
            ))
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.gymBroNeutral900)

            Spacer()

            if !readOnly {
                Button { prefillModalFromPrevious(set) } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .frame(width: 32, height: 32)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gymBroNeutral200, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button { Task { await repeatPreviousSet(set, on: exercise) } } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F59E0B"))
                            .frame(width: 32, height: 32)
                            .shadow(color: Color(hex: "F59E0B").opacity(0.3), radius: 4, y: 2)
                        Image(systemName: "repeat")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    /// Open the existing Log Set modal pre-filled with a previous set's
    /// values. User can edit weight/reps and confirm to log in the current
    /// session. `editingSetInfo`/`editingRoundIndex` cleared so it's an
    /// add-new-set flow, not an edit-existing-set flow.
    private func prefillModalFromPrevious(_ set: PreviousSet) {
        addSetWeight = set.weight.map { $0.formattedWeight } ?? ""
        addSetReps = "\(set.reps)"
        addSetIsBodyweight = set.isBodyweight
        editingSetInfo = nil
        editingRoundIndex = nil
        showAddSetSheet = true
    }

    /// Logs the previous set as-is in the current session.
    private func repeatPreviousSet(_ set: PreviousSet, on exercise: ActiveSessionExercise) async {
        await viewModel.logSet(
            exerciseId: exercise.id,
            weight: set.isBodyweight ? nil : set.weight,
            weightUnit: set.weightUnit,
            reps: set.reps,
            isBodyweight: set.isBodyweight
        )
        sessionManager.startRestTimer()
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
}
