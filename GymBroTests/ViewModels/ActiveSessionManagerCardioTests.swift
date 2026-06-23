//
//  ActiveSessionManagerCardioTests.swift
//  GymBroTests
//
//  Created by Claude Code on 2026-06-22.
//
//  Covers the dedicated cardio timer on ActiveSessionManager: the
//  single-cardio guard (only one cardio recorded at a time), the
//  timestamp-anchored elapsed math (which is what survives backgrounding
//  / app-kill), and pause / resume / end transitions.
//

import Testing
import Foundation
@testable import GymJam

@Suite("ActiveSessionManager Cardio")
@MainActor
struct ActiveSessionManagerCardioTests {

    /// Fresh, isolated manager per test — no shared singleton state.
    private func makeManager() -> ActiveSessionManager {
        ActiveSessionManager(
            appDataState: AppDataState(networkService: MockNetworkService()),
            liveActivityService: LiveActivityService()
        )
    }

    // MARK: - Single-cardio guard

    @Test("Starting cardio with nothing in flight begins a fresh recording")
    func testStartCardioBeginsRecording() {
        let manager = makeManager()
        let started = manager.startCardio(exerciseId: "A")
        #expect(started == true)
        #expect(manager.runningCardioExerciseId == "A")
    }

    @Test("A second cardio is rejected while another is recording")
    func testSecondCardioRejected() {
        let manager = makeManager()
        #expect(manager.startCardio(exerciseId: "A") == true)

        let second = manager.startCardio(exerciseId: "B")
        #expect(second == false)
        // The original recording is untouched — never clobbered.
        #expect(manager.runningCardioExerciseId == "A")
    }

    @Test("Re-tapping start for the already-recording exercise is a no-op")
    func testSameExerciseReStartRejected() {
        let manager = makeManager()
        #expect(manager.startCardio(exerciseId: "A") == true)
        #expect(manager.startCardio(exerciseId: "A") == false)
        #expect(manager.runningCardioExerciseId == "A")
    }

    @Test("Ending a cardio clears the guard so a new one can start")
    func testEndClearsGuard() {
        let manager = makeManager()
        #expect(manager.startCardio(exerciseId: "A") == true)

        let total = manager.endCardio()
        #expect(total >= 0)
        #expect(manager.runningCardioExerciseId == nil)

        // With nothing in flight, a different cardio may now start.
        #expect(manager.startCardio(exerciseId: "B") == true)
        #expect(manager.runningCardioExerciseId == "B")
    }

    // MARK: - Timestamp-anchored elapsed (survives backgrounding)

    @Test("Elapsed is computed from the start timestamp, not a live counter")
    func testElapsedFromStartDate() {
        let manager = makeManager()
        #expect(manager.startCardio(exerciseId: "A") == true)

        let start = try! #require(manager.cardioRecording?.startDate)
        // Simulate the app being backgrounded for 65s then reopened: the
        // elapsed reads correctly off the anchor even though no timer ran.
        let elapsed = manager.currentCardioElapsed(at: start.addingTimeInterval(65))
        #expect(elapsed == 65)
    }

    @Test("Pausing banks time and freezes the clock")
    func testPauseFreezesClock() {
        let manager = makeManager()
        #expect(manager.startCardio(exerciseId: "A") == true)

        manager.pauseCardio()
        #expect(manager.cardioRecording?.isPaused == true)
        #expect(manager.cardioRecording?.startDate == nil)

        // While paused, advancing `now` does not advance elapsed.
        let e1 = manager.currentCardioElapsed(at: Date().addingTimeInterval(100))
        let e2 = manager.currentCardioElapsed(at: Date().addingTimeInterval(500))
        #expect(e1 == e2)
    }

    @Test("Resuming re-arms the clock")
    func testResumeRearmsClock() {
        let manager = makeManager()
        #expect(manager.startCardio(exerciseId: "A") == true)
        manager.pauseCardio()
        manager.resumeCardio()

        #expect(manager.cardioRecording?.isPaused == false)
        #expect(manager.cardioRecording?.startDate != nil)
    }
}
