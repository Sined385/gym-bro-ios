import SwiftUI

struct SessionPlanView: View {
    @ObservedObject var viewModel: SessionFlowViewModel
    @EnvironmentObject var sessionManager: ActiveSessionManager
    @EnvironmentObject var favoritesService: FavoritesService
    var onCollapse: () -> Void
    var onAddExercise: () -> Void
    var onTapExercise: (String) -> Void
    var onTapSuperset: (String) -> Void
    var onStartWorkout: () -> Void
    var onEndWorkout: () -> Void
    var onSaveTemplate: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 14) {
                // Back button — collapse workout
                Button { onCollapse() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.gymBroNeutral100, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                    }
                }
                .buttonStyle(.plain)

                Text("Workout Plan")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Spacer()

                Button { onSaveTemplate() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.gymBroNeutral100, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                        Image(systemName: "bookmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                    }
                }
                .buttonStyle(.plain)

                if sessionManager.isWorkoutStarted {
                    TimerBadge(time: sessionManager.formattedTime)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)

            // Exercise list — custom drag/drop on a LazyVStack so the lifted
            // card stays at its real size with no system halo/double-shadow
            // (SwiftUI List.onMove looked ugly with our card chrome). The
            // reorder is local-only; the new step_number persists via the
            // standard completeSessionFull payload on workout completion.
            ScrollView(.vertical, showsIndicators: false) {
                ReorderableExerciseStack(
                    exercises: viewModel.standaloneExercises,
                    onReorder: { from, to in
                        Task { await viewModel.reorderStandaloneExercises(from: from, to: to) }
                    },
                    onTap: { onTapExercise($0) },
                    onDelete: { id in
                        Task { await viewModel.removeExercise(id) }
                    },
                    cardBuilder: { ex in
                        AnyView(exerciseCardContent(ex))
                    }
                )

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.supersetGroups) { group in
                        SwipeToDeleteCard {
                            supersetCard(group)
                                .onTapGesture { onTapSuperset(group.id) }
                        } onDelete: {
                            Task { await viewModel.removeSuperset(group.id) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, viewModel.standaloneExercises.isEmpty ? 0 : 12)
                .padding(.bottom, 120)
            }

            Spacer()

            // Bottom bar
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Add Exercise button — round when exercises exist
                    Button(action: onAddExercise) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 28, height: 28)
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 64, height: 64)
                        .background(
                            LinearGradient(
                                colors: [.gymBroPrimary, .gymBroPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.gymBroPrimary.opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)

                    if sessionManager.isWorkoutStarted {
                        // Active session with ≥1 exercise — Complete is the
                        // primary path; cancelling now requires swiping all
                        // exercises off first (which falls back to SessionStartedView).
                        Button(action: onEndWorkout) {
                            HStack(spacing: 8) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Complete Workout")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(Color(hex: "2D3240"))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Pre-active: exercises queued but timer not started yet.
                        Button(action: onStartWorkout) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Start Workout")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(Color(hex: "2D3240"))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }

            // Floating rest timer bar
            if let remaining = sessionManager.restTimeRemaining {
                restTimerBar(remaining)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: sessionManager.restTimeRemaining)
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Exercise Card Content

    private func exerciseCardContent(_ exercise: ActiveSessionExercise) -> some View {
        HStack(spacing: 16) {
            // Accent bar
            RoundedRectangle(cornerRadius: 100)
                .fill(Color(hex: exercise.accentColor))
                .frame(width: 6, height: 56)

            // Exercise image
            exerciseImage(exercise.imageUrl)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .lineLimit(1)
                    .tracking(-0.3)

                // Sets badge
                let completedSets = exercise.sets.filter { $0.isCompleted }.count
                let hasTarget = exercise.targetSets > 0
                let allDone = hasTarget && completedSets >= exercise.targetSets
                Text(hasTarget ? "\(completedSets) / \(exercise.targetSets) SETS" : "\(completedSets) SETS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(allDone ? Color(hex: "30C08D") : Color(hex: "737373"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(allDone ? Color(hex: "30C08D").opacity(0.1) : Color(hex: "F5F5F5"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            if let libraryId = exercise.libraryExerciseId {
                favoriteHeart(libraryExerciseId: libraryId)
            }

            if exercise.targetSets > 0 && exercise.sets.filter({ $0.isCompleted }).count >= exercise.targetSets {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "30C08D"))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "D4D4D4"))
            }
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 1)
        .frame(minHeight: 72)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    private func favoriteHeart(libraryExerciseId: String) -> some View {
        let isFavorite = favoritesService.isFavorite(libraryExerciseId)
        return Image(systemName: isFavorite ? "heart.fill" : "heart")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(isFavorite ? .gymBroPrimary : .gymBroNeutral400)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    Task { await favoritesService.toggle(exerciseId: libraryExerciseId) }
                }
            )
    }

    @ViewBuilder
    private func exerciseImage(_ imageUrl: String?) -> some View {
        if let imageUrl, let url = URL(string: imageUrl) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                exercisePlaceholder
            } failure: {
                exercisePlaceholder
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            exercisePlaceholder
        }
    }

    private var exercisePlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(hex: "F5F5F5"))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "D4D4D4"))
            )
    }

    // MARK: - Superset Card

    private func supersetCard(_ group: SupersetGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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

            // Exercises in superset
            ForEach(group.exercises) { exercise in
                HStack(spacing: 10) {
                    Text(exercise.supersetOrder ?? "")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "7A82F6"))
                        .frame(width: 20)

                    Text(exercise.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)

                    Spacer()

                    Text("\(exercise.sets.count) sets")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroNeutral400)
                }
            }

            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroNeutral400)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "7A82F6").opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Rest Timer Bar

    private func restTimerBar(_ remaining: Int) -> some View {
        let purpleAccent = Color(hex: "7A82F6")
        let minutes = remaining / 60
        let seconds = remaining % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)

        return HStack {
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
        .padding(.horizontal, 16)
    }
}

// MARK: - ReorderableExerciseStack

/// Custom long-press-and-drag reorder for the active workout's standalone
/// exercises. Built on a LazyVStack with hand-rolled gestures so we control
/// the lifted-card visuals end-to-end — SwiftUI's List drag preview painted
/// a haloed double-shadow on top of our card chrome, which looked sloppy.
///
/// Long-press a card → haptic + the card lifts (scale + shadow). Drag up
/// or down → neighbouring cards spring out of the way in real time. Release
/// → card snaps into its new slot and the reorder closure fires.
struct ReorderableExerciseStack: View {
    let exercises: [ActiveSessionExercise]
    let onReorder: (IndexSet, Int) -> Void
    let onTap: (String) -> Void
    let onDelete: (String) -> Void
    let cardBuilder: (ActiveSessionExercise) -> AnyView

    private let cardSpacing: CGFloat = 12
    /// Approximate card height including spacing. Used purely to compute the
    /// "where would the drop land" math, so a small over-estimate is fine —
    /// each card's true visible size still drives the layout.
    private let cardSlotHeight: CGFloat = 88

    @State private var draggedID: String? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var draggedFromIndex: Int = 0

    var body: some View {
        LazyVStack(spacing: cardSpacing) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, exercise in
                let isDragged = draggedID == exercise.id
                SwipeToDeleteCard {
                    cardBuilder(exercise)
                        .onTapGesture { onTap(exercise.id) }
                } onDelete: {
                    onDelete(exercise.id)
                }
                .scaleEffect(isDragged ? 1.03 : 1.0)
                .shadow(
                    color: .black.opacity(isDragged ? 0.18 : 0),
                    radius: isDragged ? 22 : 0,
                    x: 0,
                    y: isDragged ? 12 : 0
                )
                .offset(y: yOffset(for: idx, exerciseId: exercise.id))
                .zIndex(isDragged ? 100 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: draggedID)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: dragOffset)
                .gesture(reorderGesture(for: exercise.id, at: idx))
            }
        }
        .padding(.horizontal, 20)
        // Headroom so a lifted first card (scale 1.03 + shadow) doesn't poke
        // up under the screen header. Same amount on the bottom keeps the
        // section visually centered between header and superset block.
        .padding(.vertical, 10)
    }

    private var targetIndex: Int {
        let rowH = cardSlotHeight + cardSpacing
        let shift = Int((dragOffset / rowH).rounded())
        return max(0, min(exercises.count - 1, draggedFromIndex + shift))
    }

    private func yOffset(for idx: Int, exerciseId: String) -> CGFloat {
        guard draggedID != nil else { return 0 }
        if exerciseId == draggedID { return dragOffset }
        let rowH = cardSlotHeight + cardSpacing
        let target = targetIndex
        if draggedFromIndex < target {
            // Dragging downward — cards between original and target shift up.
            if idx > draggedFromIndex && idx <= target { return -rowH }
        } else if draggedFromIndex > target {
            // Dragging upward — cards between target and original shift down.
            if idx < draggedFromIndex && idx >= target { return rowH }
        }
        return 0
    }

    private func reorderGesture(for id: String, at idx: Int) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first:
                    break
                case .second(let pressed, let drag):
                    if pressed && draggedID == nil {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        draggedID = id
                        draggedFromIndex = idx
                    }
                    if let drag {
                        dragOffset = drag.translation.height
                    }
                }
            }
            .onEnded { _ in
                guard let liftedID = draggedID else { return }
                let target = targetIndex
                let from = draggedFromIndex
                let rowH = cardSlotHeight + cardSpacing
                // Snap the dragged card visually to the target slot *before*
                // mutating the array. That way the array reorder happens
                // while the card is already where its new index will place
                // it — no teleport, no jump.
                let snappedOffset = CGFloat(target - from) * rowH
                let animation = Animation.spring(response: 0.32, dampingFraction: 0.85)
                withAnimation(animation) {
                    dragOffset = snappedOffset
                }
                let settleDuration: TimeInterval = 0.32
                DispatchQueue.main.asyncAfter(deadline: .now() + settleDuration) {
                    if target != from {
                        // IndexSet move semantics: target offset is interpreted
                        // after removal, so account for that when sliding down.
                        let dest = target > from ? target + 1 : target
                        onReorder(IndexSet(integer: from), dest)
                    }
                    // Reset transaction without animation — the card's new
                    // index already places it at the snapped position, so
                    // zeroing dragOffset doesn't move it on screen.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if draggedID == liftedID {
                            draggedID = nil
                            dragOffset = 0
                        }
                    }
                }
            }
    }
}
