//
//  SessionFlowContainer.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-17.
//

import SwiftUI
import Combine

// MARK: - Session Route

enum SessionRoute: Hashable {
    case exerciseLibrary
    case supersetSelection
    case exerciseLogging(exerciseId: String)
    case supersetLogging(groupId: String)
    case createCustomExercise
    case workoutFeedback
}

// MARK: - SessionFlowContainer

struct SessionFlowContainer: View {

    let sessionId: String
    let sessionTitle: String
    let initialExercises: [DashboardExercise]
    let restoredExercises: [ActiveSessionExercise]?
    let restoredFeedback: (effort: Int, energy: Int, pain: String)?
    let onCollapse: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var sessionManager: ActiveSessionManager
    @StateObject private var viewModel: SessionFlowViewModel
    @StateObject private var libraryViewModel: ExerciseLibraryViewModel = DependencyContainer.shared.resolve(ExerciseLibraryViewModel.self)
    @State private var navigationPath = NavigationPath()
    @State private var showSaveTemplate = false
    @State private var showCancelConfirmation = false

    init(sessionId: String, sessionTitle: String, initialExercises: [DashboardExercise] = [], restoredExercises: [ActiveSessionExercise]? = nil, restoredFeedback: (effort: Int, energy: Int, pain: String)? = nil, onCollapse: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.initialExercises = initialExercises
        self.restoredExercises = restoredExercises
        self.restoredFeedback = restoredFeedback
        self.onCollapse = onCollapse
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: SessionFlowViewModel(
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            networkService: DependencyContainer.shared.resolve(NetworkServiceProtocol.self),
            sessionManager: DependencyContainer.shared.resolve(ActiveSessionManager.self),
            healthKitService: DependencyContainer.shared.resolve(HealthKitServiceProtocol.self),
            analyticsService: DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self),
            completionCacheService: DependencyContainer.shared.resolve(SessionCompletionCacheServiceProtocol.self),
            initialExercises: initialExercises,
            restoredExercises: restoredExercises,
            restoredFeedback: restoredFeedback
        ))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.hasExercises {
                    SessionPlanView(
                        viewModel: viewModel,
                        onCollapse: onCollapse,
                        onAddExercise: { navigationPath.append(SessionRoute.exerciseLibrary) },
                        onTapExercise: { exerciseId in
                            navigationPath.append(SessionRoute.exerciseLogging(exerciseId: exerciseId))
                        },
                        onTapSuperset: { groupId in
                            navigationPath.append(SessionRoute.supersetLogging(groupId: groupId))
                        },
                        onStartWorkout: { sessionManager.startWorkout() },
                        onEndWorkout: { navigationPath.append(SessionRoute.workoutFeedback) },
                        onSaveTemplate: { showSaveTemplate = true },
                        onCancel: requestCancel
                    )
                } else {
                    SessionStartedView(
                        viewModel: viewModel,
                        onAddExercise: { navigationPath.append(SessionRoute.exerciseLibrary) },
                        onStartWorkout: { sessionManager.startWorkout() },
                        onCancelWorkout: requestCancel,
                        // Empty session: top X ends the session too. Collapsing
                        // to mini-player isn't useful with nothing logged, and
                        // pre-active state otherwise has no exit path.
                        onDismiss: onDismiss
                    )
                }
            }
            .task { await libraryViewModel.loadExercises() }
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .exerciseLibrary:
                    ExerciseLibraryView(
                        viewModel: libraryViewModel,
                        addedExerciseIds: Set(viewModel.exercises.compactMap { $0.libraryExerciseId }),
                        onExerciseSelected: { item in
                            // Tap toggles membership: if already in the workout,
                            // tapping again removes it. Lets the user undo a
                            // mis-tap without leaving the library.
                            if let existing = viewModel.exercises.first(where: { $0.libraryExerciseId == item.id }) {
                                Task { await viewModel.removeExercise(existing.id) }
                            } else {
                                Task { await viewModel.addExercise(item) }
                            }
                        },
                        onStartSuperset: {
                            guard viewModel.subscriptionManager.requireFeature(.supersets) else { return }
                            navigationPath.append(SessionRoute.supersetSelection)
                        },
                        onCreateCustom: {
                            guard libraryViewModel.subscriptionManager.requireFeature(.customExercises) else { return }
                            navigationPath.append(SessionRoute.createCustomExercise)
                        }
                    )
                case .supersetSelection:
                    SupersetSelectionView(
                        libraryViewModel: libraryViewModel,
                        addedExerciseIds: Set(viewModel.exercises.compactMap { $0.libraryExerciseId }),
                        onSave: { items in
                            Task {
                                await viewModel.addSupersetFromLibrary(items)
                                // Pop back to plan
                                navigationPath = NavigationPath()
                            }
                        }
                    )
                case .exerciseLogging(let exerciseId):
                    ExerciseLoggingView(
                        viewModel: viewModel,
                        exerciseId: exerciseId,
                        onSwitchToExercise: { newId in
                            replaceTop(with: .exerciseLogging(exerciseId: newId))
                        },
                        onSwitchToSuperset: { groupId in
                            replaceTop(with: .supersetLogging(groupId: groupId))
                        },
                        onEndWorkout: { navigationPath.append(SessionRoute.workoutFeedback) }
                    )
                case .supersetLogging(let groupId):
                    ExerciseLoggingView(
                        viewModel: viewModel,
                        supersetGroupId: groupId,
                        onSwitchToExercise: { newId in
                            replaceTop(with: .exerciseLogging(exerciseId: newId))
                        },
                        onSwitchToSuperset: { gid in
                            replaceTop(with: .supersetLogging(groupId: gid))
                        },
                        onEndWorkout: { navigationPath.append(SessionRoute.workoutFeedback) }
                    )
                case .createCustomExercise:
                    CreateCustomExerciseView(
                        libraryViewModel: libraryViewModel,
                        sessionViewModel: viewModel,
                        onComplete: {
                            // Pop back to plan
                            navigationPath = NavigationPath()
                        }
                    )
                case .workoutFeedback:
                    WorkoutFeedbackView(
                        viewModel: viewModel,
                        onDismiss: onDismiss
                    )
                }
            }
        }
        .sheet(isPresented: $showSaveTemplate) {
            SaveTemplateSheet(
                defaultName: sessionTitle,
                onSave: { name in
                    let vm: WorkoutTemplatesViewModel = DependencyContainer.shared.resolve(WorkoutTemplatesViewModel.self)
                    Task {
                        let _ = await vm.saveTemplate(name: name, sessionId: sessionId)
                    }
                }
            )
        }
        .alert("End workout?", isPresented: $showCancelConfirmation) {
            Button("Keep training", role: .cancel) { }
            Button("End workout", role: .destructive) { cancelAndDismiss() }
        } message: {
            Text("Your logged sets will be lost.")
        }
    }

    /// Swap the top of the nav stack rather than push, so tapping "Next"
    /// on a logging screen doesn't grow the back stack with every jump —
    /// back still goes straight to the plan view.
    private func replaceTop(with route: SessionRoute) {
        if !navigationPath.isEmpty { navigationPath.removeLast() }
        navigationPath.append(route)
    }

    /// Confirmation step before nuking an in-progress workout. The X
    /// used to fire `/cancel` instantly — users tapping it by accident
    /// (mistaking it for "close modal") lost their logged sets in a
    /// single tap, and analytics show this happened repeatedly in
    /// real-world traces. A two-tap confirmation makes it intentional.
    /// Skipped while the workout hasn't been started yet (no sets to
    /// lose), so the SessionStartedView X still dismisses cleanly.
    private func requestCancel() {
        if sessionManager.isWorkoutStarted {
            showCancelConfirmation = true
        } else {
            cancelAndDismiss()
        }
    }

    /// Fires the server-side cancel and then tears down the local session.
    /// Dismiss runs regardless of network outcome so the user isn't trapped.
    /// The backend's /cancel is idempotent (returns 200 even when the row
    /// doesn't exist) so plan-day sessions — which after the "store on
    /// complete" refactor never have a server row — are also safe.
    private func cancelAndDismiss() {
        Task {
            _ = await viewModel.cancelSession()
            onDismiss()
        }
    }

}
