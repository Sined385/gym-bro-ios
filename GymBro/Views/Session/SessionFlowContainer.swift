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

    @StateObject private var viewModel: SessionFlowViewModel
    @StateObject private var libraryViewModel: ExerciseLibraryViewModel = DependencyContainer.shared.resolve(ExerciseLibraryViewModel.self)
    @State private var navigationPath = NavigationPath()

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
                        onEndWorkout: { navigationPath.append(SessionRoute.workoutFeedback) },
                        onCancelWorkout: onDismiss
                    )
                } else {
                    SessionStartedView(
                        viewModel: viewModel,
                        onStartExercise: { navigationPath.append(SessionRoute.exerciseLibrary) },
                        onDismiss: onCollapse
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
                            Task {
                                await viewModel.addExercise(item)
                                let addedExercise = viewModel.exercises.last
                                guard !navigationPath.isEmpty else { return }
                                navigationPath.removeLast()
                                if let ex = addedExercise {
                                    navigationPath.append(SessionRoute.exerciseLogging(exerciseId: ex.id))
                                }
                            }
                        },
                        onStartSuperset: {
                            navigationPath.append(SessionRoute.supersetSelection)
                        },
                        onCreateCustom: {
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
                        exerciseId: exerciseId
                    )
                case .supersetLogging(let groupId):
                    ExerciseLoggingView(
                        viewModel: viewModel,
                        supersetGroupId: groupId
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
    }
}
