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

            // Exercise list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // Standalone exercises
                    ForEach(viewModel.standaloneExercises) { exercise in
                        swipeableExerciseCard(exercise)
                    }

                    // Superset groups
                    ForEach(viewModel.supersetGroups) { group in
                        SwipeToDeleteCard {
                            supersetCard(group)
                                .onTapGesture {
                                    onTapSuperset(group.id)
                                }
                        } onDelete: {
                            Task { await viewModel.removeSuperset(group.id) }
                        }
                    }
                }
                .padding(.horizontal, 20)
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

    // MARK: - Swipeable Exercise Card

    private func swipeableExerciseCard(_ exercise: ActiveSessionExercise) -> some View {
        SwipeToDeleteCard {
            exerciseCardContent(exercise)
                .onTapGesture {
                    onTapExercise(exercise.id)
                }
        } onDelete: {
            Task { await viewModel.removeExercise(exercise.id) }
        }
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
