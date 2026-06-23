//
//  CardioMetricSpecTests.swift
//  GymBroTests
//
//  Created by Claude Code on 2026-06-22.
//
//  The "global cardio pattern" seam: family detection + per-family
//  metric spec (which completion metrics each cardio type logs).
//

import Testing
@testable import GymJam

@Suite("Cardio Metric Spec")
struct CardioMetricSpecTests {

    @Test("Walking, Treadmill detects as the treadmill family")
    func testWalkingDetectsTreadmill() {
        let family = CardioFamily.detect(name: "Walking, Treadmill", equipment: "Machine")
        #expect(family == .treadmill)
    }

    @Test("Distance-based families log distance on completion")
    func testDistanceFamiliesLogDistance() {
        for family in [CardioFamily.treadmill, .gpsEndurance, .gpsWheeled, .seatedMachine, .rowing] {
            #expect(CardioMetricSpec.spec(for: family).logsDistance == true)
        }
    }

    @Test("Time-only families do not log distance")
    func testTimeOnlyFamiliesSkipDistance() {
        for family in [CardioFamily.interval, .climber] {
            #expect(CardioMetricSpec.spec(for: family).logsDistance == false)
        }
    }

    @Test("Every family resolves a positive MET for calorie math")
    func testAllFamiliesHavePositiveMET() {
        let families: [CardioFamily] = [
            .gpsEndurance, .gpsWheeled, .treadmill, .seatedMachine, .rowing, .climber, .interval,
        ]
        for family in families {
            #expect(CardioMetricSpec.spec(for: family).met > 0)
        }
    }

    @Test("Walking treadmill resolves a 5 km/h target speed")
    func testWalkingTargetSpeed() {
        let spec = CardioMetricSpec.spec(for: .treadmill, exerciseName: "Walking, Treadmill")
        #expect(spec.targetSpeedKmh == 5.0)
    }

    @Test("Running resolves a faster target speed than walking")
    func testRunningFasterThanWalking() {
        let walk = CardioMetricSpec.spec(for: .treadmill, exerciseName: "Walking, Treadmill")
        let run = CardioMetricSpec.spec(for: .treadmill, exerciseName: "Running, Treadmill")
        #expect((run.targetSpeedKmh ?? 0) > (walk.targetSpeedKmh ?? 0))
    }

    @Test("Speed-less families expose no target speed")
    func testSpeedlessFamilies() {
        for family in [CardioFamily.rowing, .climber, .interval, .seatedMachine] {
            #expect(CardioMetricSpec.spec(for: family).targetSpeedKmh == nil)
        }
    }
}
