//
//  CardioMetricSpec.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-22.
//
//  The "global cardio pattern" extensibility seam. A CardioMetricSpec
//  declares, per CardioFamily, the data we need to render the live
//  metric body (the calorie MET factor) and what the user is asked to
//  log when they finish (e.g. distance for walking/running).
//
//  This replaces the previous one-real-case-plus-placeholder switch in
//  CardioWorkoutView: every family now plugs into one reusable
//  CardioMetricsView, and "different cardio exercises log different
//  things" is data, not bespoke views.
//

import Foundation

/// A single logged/displayed cardio metric. `time` is always tracked
/// live (the timer); the others are family-dependent.
enum CardioMetricKind: String, CaseIterable {
    case time
    case distance
    case pace
    case calories
}

/// Per-family cardio configuration. Tiny on purpose — extend the
/// completion list (or add fields) as new cardio types need richer
/// logging.
struct CardioMetricSpec {
    /// MET (metabolic equivalent) used for the calorie estimate
    /// `kcal = MET × bodyWeightKg × hours`. Family-level granularity.
    let met: Double

    /// Metrics the user is asked to log when they tap Done. Walking and
    /// the other distance-based families prompt for `.distance`;
    /// interval/climber families log time only (no meaningful distance).
    let completionMetrics: [CardioMetricKind]

    /// Suggested target speed in km/h, shown alongside the duration
    /// target so the user knows what pace to set the machine to. Nil for
    /// families where a km/h target isn't meaningful (rowing, climber,
    /// interval) — those just hide the speed.
    let targetSpeedKmh: Double?

    /// True when the finish flow should present the distance-entry sheet.
    var logsDistance: Bool { completionMetrics.contains(.distance) }

    /// Resolve the spec for a family + exercise name. Walking
    /// (`.treadmill`) is the first fully-supported type; the rest get
    /// sensible defaults so they render through the same reusable view.
    /// `exerciseName` refines the target speed for foot-based families
    /// (walk vs jog vs run share the treadmill / GPS family).
    static func spec(
        for family: CardioFamily,
        exerciseName: String = "",
    ) -> CardioMetricSpec {
        switch family {
        case .gpsEndurance:
            // Outdoor walk / run.
            return CardioMetricSpec(
                met: 7.0,
                completionMetrics: [.distance],
                targetSpeedKmh: footSpeedKmh(for: exerciseName),
            )
        case .gpsWheeled:
            // Outdoor cycling / skating.
            return CardioMetricSpec(
                met: 6.8, completionMetrics: [.distance], targetSpeedKmh: 20.0,
            )
        case .treadmill:
            // Treadmill walking / jogging / running — the reference type.
            return CardioMetricSpec(
                met: 6.0,
                completionMetrics: [.distance],
                targetSpeedKmh: footSpeedKmh(for: exerciseName),
            )
        case .seatedMachine:
            // Stationary / recumbent bike, elliptical (preserves prior MET).
            return CardioMetricSpec(
                met: 7.0, completionMetrics: [.distance], targetSpeedKmh: nil,
            )
        case .rowing:
            return CardioMetricSpec(
                met: 7.0, completionMetrics: [.distance], targetSpeedKmh: nil,
            )
        case .climber:
            // Stairmaster / step mill — floors, not distance.
            return CardioMetricSpec(met: 9.0, completionMetrics: [], targetSpeedKmh: nil)
        case .interval:
            // Prowler / rope jumping — time only.
            return CardioMetricSpec(met: 8.0, completionMetrics: [], targetSpeedKmh: nil)
        }
    }

    /// A sensible target km/h for foot-based cardio, inferred from the
    /// exercise name. Walking is the reference type (~5 km/h brisk walk).
    private static func footSpeedKmh(for name: String) -> Double {
        let n = name.lowercased()
        if n.contains("walk") { return 5.0 }
        if n.contains("jog") { return 8.0 }
        if n.contains("run") || n.contains("sprint") { return 10.0 }
        return 6.0
    }
}
