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
    var onCancel: () -> Void

    @State private var showDiscardConfirm = false

    // Live reorder state. The badge inside each card owns a sequenced
    // long-press + drag gesture; while a card is lifted the parent
    // applies a finger-tracking offset to it and shifts its siblings
    // by one slot's height so the list visually reflows as the finger
    // moves. The whole interaction lives on SessionPlanView (not on a
    // child wrapper) so the offset/animation modifiers can be applied
    // to the row directly without an AnyView round-trip.
    @State private var draggedID: String? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var draggedFromIndex: Int = 0
    private let cardSpacing: CGFloat = 12
    // Approximate row height including spacing — used purely for the
    // "where would the drop land" math. A small over-estimate is fine
    // because each card's real visible size still drives layout.
    private let cardSlotHeight: CGFloat = 88

    var body: some View {
        VStack(spacing: 0) {
            topBar

            // Custom long-press + drag, gesture-bound to the badge inside
            // each card. While dragging, the lifted card follows the finger
            // and its siblings spring one slot up or down so the user can
            // see exactly where the drop will land. On release the card
            // snaps to the target slot and the view model commits the
            // reorder.
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: cardSpacing) {
                    ForEach(Array(viewModel.standaloneExercises.enumerated()), id: \.element.id) { idx, exercise in
                        let isDragged = draggedID == exercise.id
                        SwipeToDeleteCard {
                            exerciseCardContent(
                                exercise,
                                dragHandle: AnyView(dragBadge(for: exercise.id, at: idx)),
                            )
                            .onTapGesture { onTapExercise(exercise.id) }
                        } onDelete: {
                            Task { await viewModel.removeExercise(exercise.id) }
                        }
                        .scaleEffect(isDragged ? 1.03 : 1.0)
                        .shadow(
                            color: .black.opacity(isDragged ? 0.18 : 0),
                            radius: isDragged ? 22 : 0,
                            x: 0,
                            y: isDragged ? 12 : 0,
                        )
                        .offset(y: yOffset(for: idx, exerciseId: exercise.id))
                        .zIndex(isDragged ? 100 : 0)
                        // Spring on lift/drop only.
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: draggedID)
                        // Siblings spring smoothly into place as the drop
                        // target changes. The dragged card itself must NOT
                        // animate on slot crossings — its offset is driven
                        // by dragOffset and needs to track the finger 1:1;
                        // passing nil disables the animation it would
                        // otherwise inherit on each crossing.
                        .animation(
                            isDragged
                                ? nil
                                : .spring(response: 0.3, dampingFraction: 0.85),
                            value: targetIndex,
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                ForEach(viewModel.supersetGroups) { group in
                    SwipeToDeleteCard {
                        supersetCard(group)
                            .onTapGesture { onTapSuperset(group.id) }
                    } onDelete: {
                        Task { await viewModel.removeSuperset(group.id) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomInset
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .animation(.spring(response: 0.4), value: sessionManager.restTimeRemaining)
        .confirmationDialog(
            "Discard workout?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { onCancel() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Your logged sets will be lost.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
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

            // Overflow menu — save + discard live here so the top bar stays
            // narrow enough for the timer on smaller devices (iPhone SE etc).
            Menu {
                Button { onSaveTemplate() } label: {
                    Label("Save as Template", systemImage: "bookmark")
                }
                Button(role: .destructive) { showDiscardConfirm = true } label: {
                    Label("Discard Workout", systemImage: "trash")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.gymBroNeutral100, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                }
            }
            .buttonStyle(.plain)

            if sessionManager.isWorkoutStarted {
                TimerBadge(time: sessionManager.formattedTime)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color.gymBroBackground)
    }

    // MARK: - Bottom Inset (rest timer + action bar)

    private var bottomInset: some View {
        VStack(spacing: 12) {
            if let remaining = sessionManager.restTimeRemaining {
                restTimerBar(remaining)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            bottomBar
        }
        .background(Color.gymBroBackground)
    }

    private var bottomBar: some View {
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
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Exercise Card Content

    private func exerciseCardContent(
        _ exercise: ActiveSessionExercise,
        dragHandle: AnyView = AnyView(EmptyView()),
    ) -> some View {
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

            dragHandle

            if exercise.targetSets > 0 && exercise.sets.filter({ $0.isCompleted }).count >= exercise.targetSets {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "30C08D"))
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

    // Badge that lives just right of the heart inside each card. A
    // sequenced long-press → drag gesture is attached only to this
    // 36×44 hit area, so the card body remains tappable to open the
    // logging view and horizontal swipes still reach SwipeToDeleteCard.
    private func dragBadge(for id: String, at idx: Int) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(hex: "B0B0B0"))
            .frame(width: 36, height: 44)
            .contentShape(Rectangle())
            .gesture(reorderGesture(for: id, at: idx))
    }

    private var targetIndex: Int {
        let rowH = cardSlotHeight + cardSpacing
        let shift = Int((dragOffset / rowH).rounded())
        return max(
            0,
            min(viewModel.standaloneExercises.count - 1, draggedFromIndex + shift),
        )
    }

    private func yOffset(for idx: Int, exerciseId: String) -> CGFloat {
        guard draggedID != nil else { return 0 }
        if exerciseId == draggedID { return dragOffset }
        let rowH = cardSlotHeight + cardSpacing
        let target = targetIndex
        if draggedFromIndex < target {
            // Dragging downward — cards between source and target shift up.
            if idx > draggedFromIndex && idx <= target { return -rowH }
        } else if draggedFromIndex > target {
            // Dragging upward — cards between target and source shift down.
            if idx < draggedFromIndex && idx >= target { return rowH }
        }
        return 0
    }

    private func reorderGesture(for id: String, at idx: Int) -> some Gesture {
        // `.global` is critical: the dragged card is offset by dragOffset,
        // so a `.local` DragGesture would measure translation against the
        // moving card and feed a jittering value back into dragOffset.
        // Screen-relative translation avoids that feedback loop.
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
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
                // mutating the array so the array reorder happens while the
                // card is already where its new index will place it — no
                // teleport, no jump.
                let snappedOffset = CGFloat(target - from) * rowH
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    dragOffset = snappedOffset
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    if target != from {
                        // IndexSet move semantics: target offset is interpreted
                        // after removal, so account for that when sliding down.
                        let dest = target > from ? target + 1 : target
                        Task {
                            await viewModel.reorderStandaloneExercises(
                                from: IndexSet(integer: from),
                                to: dest,
                            )
                        }
                    }
                    // Reset without animation — the card's new index already
                    // places it at the snapped position so zeroing dragOffset
                    // doesn't move it on screen.
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

