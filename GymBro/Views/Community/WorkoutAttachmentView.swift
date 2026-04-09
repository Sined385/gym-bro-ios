//
//  WorkoutAttachmentView.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-07.
//

import SwiftUI

struct WorkoutAttachmentView: View {
    let attachment: WorkoutAttachment
    @State private var isExpanded: Bool

    init(attachment: WorkoutAttachment, defaultExpanded: Bool = false) {
        self.attachment = attachment
        self._isExpanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }

            // Expanded content
            if isExpanded, let exercises = attachment.exercises, !exercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 8)

                    ForEach(groupedExercises, id: \.id) { group in
                        switch group {
                        case .standalone(let exercise, let index):
                            exerciseRow(exercise, index: index)
                        case .superset(let exercises, _):
                            supersetContainer(exercises)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color.gymBroPrimary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gymBroPrimary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.gymBroPrimary, Color.gymBroPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                HStack(spacing: 4) {
                    if let duration = attachment.durationMinutes {
                        Text("\(duration) MIN")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gymBroTextSecondary)
                    }
                    Text("\u{2022}")
                        .font(.system(size: 11))
                        .foregroundColor(.gymBroTextSecondary)
                    Text("\(attachment.exerciseCount) EXERCISE\(attachment.exerciseCount == 1 ? "" : "S")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gymBroTextSecondary)
                }
            }

            Spacer()

            if let rpe = attachment.rpe {
                Text("\(rpe)/10")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymBroPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gymBroPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gymBroTextSecondary)
                .rotationEffect(.degrees(isExpanded ? -180 : 0))
        }
    }

    // MARK: - Exercise Grouping

    private enum ExerciseGroup: Identifiable {
        case standalone(exercise: AttachmentExercise, index: Int)
        case superset(exercises: [(exercise: AttachmentExercise, index: Int)], groupId: String)

        var id: String {
            switch self {
            case .standalone(let exercise, _):
                return "standalone-\(exercise.name)"
            case .superset(_, let groupId):
                return "superset-\(groupId)"
            }
        }
    }

    private var groupedExercises: [ExerciseGroup] {
        guard let exercises = attachment.exercises else { return [] }

        var groups: [ExerciseGroup] = []
        var supersetMap: [String: [(exercise: AttachmentExercise, index: Int)]] = [:]
        var insertionOrder: [String] = []

        for (index, exercise) in exercises.enumerated() {
            if let groupId = exercise.supersetGroupId {
                if supersetMap[groupId] == nil {
                    insertionOrder.append(groupId)
                    supersetMap[groupId] = []
                }
                supersetMap[groupId]?.append((exercise, index))
            } else {
                // Flush any pending superset groups that appeared before this standalone
                // Actually, we need to maintain order, so use a different approach
            }
        }

        // Rebuild in order: iterate exercises, emit standalone or superset group (first time seen)
        var emittedGroups: Set<String> = []

        for (index, exercise) in exercises.enumerated() {
            if let groupId = exercise.supersetGroupId {
                if !emittedGroups.contains(groupId) {
                    emittedGroups.insert(groupId)
                    if let members = supersetMap[groupId], members.count > 1 {
                        groups.append(.superset(exercises: members, groupId: groupId))
                    } else if let members = supersetMap[groupId], let first = members.first {
                        groups.append(.standalone(exercise: first.exercise, index: first.index))
                    }
                }
            } else {
                groups.append(.standalone(exercise: exercise, index: index))
            }
        }

        return groups
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ exercise: AttachmentExercise, index: Int, orderLabel: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: exercise.accentColor ?? "#E86A75"))
                    .frame(width: 4, height: 32)

                if let orderLabel {
                    Text(orderLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "7A82F6"))
                        .frame(width: 18)
                }

                // Exercise image
                exerciseImageView(exercise.imageUrl)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .lineLimit(1)

                    if let muscleGroup = exercise.muscleGroup {
                        Text(muscleGroup.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.4)
                            .foregroundColor(.gymBroTextSecondary)
                    }
                }

                Spacer()
            }

            // Per-set chips
            setsChips(for: exercise)
                .padding(.leading, 12)
        }
    }

    // MARK: - Sets Chips

    @ViewBuilder
    private func setsChips(for exercise: AttachmentExercise) -> some View {
        if let sets = exercise.sets, !sets.isEmpty {
            FlowLayout(spacing: 4) {
                ForEach(sets) { set in
                    setChip(set)
                }
            }
        } else if let setsDisplay = exercise.setsDisplay {
            Text(setsDisplay.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(Color(hex: "737373"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "F5F5F5"))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func setChip(_ set: AttachmentSetData) -> some View {
        let text: String = {
            if let weight = set.weight, weight > 0 {
                let unit = set.weightUnit ?? "kg"
                let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(weight))"
                    : String(format: "%.1f", weight)
                return "\(weightStr)\(unit) \u{00D7} \(set.reps)"
            } else {
                return "\u{00D7} \(set.reps)"
            }
        }()

        return Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(hex: "737373"))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(hex: "F5F5F5"))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Superset Container

    private func supersetContainer(_ exercises: [(exercise: AttachmentExercise, index: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Superset badge
            HStack(spacing: 6) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("SUPERSET")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "7A82F6"))
            .clipShape(Capsule())

            ForEach(Array(exercises.enumerated()), id: \.element.exercise.name) { i, item in
                exerciseRow(
                    item.exercise,
                    index: item.index,
                    orderLabel: item.exercise.supersetOrder ?? String(Character(UnicodeScalar(65 + i)!))
                )
            }
        }
        .padding(10)
        .background(Color(hex: "7A82F6").opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "7A82F6").opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Exercise Image

    @ViewBuilder
    private func exerciseImageView(_ imageUrl: String?) -> some View {
        if let imageUrl, let url = URL(string: imageUrl) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                exerciseImagePlaceholder
            } failure: {
                exerciseImagePlaceholder
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            exerciseImagePlaceholder
        }
    }

    private var exerciseImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: "F5F5F5"))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "D4D4D4"))
            )
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private struct ArrangementResult {
        var positions: [CGPoint]
        var sizes: [CGSize]
        var size: CGSize
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return ArrangementResult(
            positions: positions,
            sizes: sizes,
            size: CGSize(width: maxWidth, height: y + rowHeight)
        )
    }
}
