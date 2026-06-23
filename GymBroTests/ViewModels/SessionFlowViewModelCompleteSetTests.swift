//
//  SessionFlowViewModelCompleteSetTests.swift
//  GymBroTests
//
//  Regression: tapping the checkmark on a strength set (e.g. pushups in a
//  home-screen quick workout) must mark the set completed. The rest timer
//  fired but the set never flipped — this isolates completeSet against the
//  same data shape the quick-workout / dashboard path produces.
//

import Testing
@testable import GymJam

@MainActor
@Suite("SessionFlowViewModel.completeSet")
struct SessionFlowViewModelCompleteSetTests {

    private func makeVM(initial: [DashboardExercise]) -> SessionFlowViewModel {
        SessionFlowViewModel(
            sessionId: "s1",
            sessionTitle: "Quick Workout",
            networkService: MockNetworkService(),
            sessionManager: ActiveSessionManager(
                appDataState: AppDataState(networkService: MockNetworkService()),
                liveActivityService: LiveActivityService()
            ),
            healthKitService: MockHealthKitService(),
            analyticsService: DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self),
            initialExercises: initial,
            isPreviewMode: true
        )
    }

    private func pushups(withProvidedSets: Bool) -> DashboardExercise {
        DashboardExercise(
            id: "ex-pushups",
            name: "Pushups",
            stepNumber: 1,
            setsDisplay: "3 × 10",
            accentColor: "#E86A75",
            libraryExerciseId: "lib-pushups",
            muscleGroup: "Chest",
            equipment: "Bodyweight",
            suggestedWeight: nil,
            imageUrl: nil,
            externalId: "Push_Up",
            sets: withProvidedSets
                ? [DashboardExerciseSet(setNumber: 1, weight: nil, weightUnit: "kg", reps: 10, isBodyweight: true)]
                : nil
        )
    }

    @Test("marks a provided bodyweight set completed")
    func testCompleteProvidedSet() async {
        let vm = makeVM(initial: [pushups(withProvidedSets: true)])
        let ex = try! #require(vm.exercises.first)
        let set = try! #require(ex.sets.first)
        #expect(set.isCompleted == false)

        await vm.completeSet(exerciseId: ex.id, setId: set.id, weight: nil, reps: 10, isBodyweight: true)

        #expect(vm.exercises.first?.sets.first?.isCompleted == true)
    }

    @Test("marks a generated (setsDisplay-expanded) set completed")
    func testCompleteGeneratedSet() async {
        let vm = makeVM(initial: [pushups(withProvidedSets: false)])
        let ex = try! #require(vm.exercises.first)
        let set = try! #require(ex.sets.first)

        await vm.completeSet(exerciseId: ex.id, setId: set.id, weight: nil, reps: 10, isBodyweight: true)

        #expect(vm.exercises.first?.sets.first?.isCompleted == true)
    }
}
