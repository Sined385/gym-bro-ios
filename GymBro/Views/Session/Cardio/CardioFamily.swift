//
//  CardioFamily.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//
//  Family taxonomy + recording-phase enum shared across the cardio screen and
//  its per-family widgets. Lifted out of ExerciseLoggingView so both the new
//  CardioWorkoutView spine and any future family content can reuse it without
//  a back-reference into the strength screen.

import SwiftUI

/// Seven cardio families described by the design spec. Family is detected
/// from the exercise name + equipment via `CardioFamily.detect(...)`.
enum CardioFamily {
    case gpsEndurance       // Trail Running / Walking
    case gpsWheeled         // Bicycling / Skating
    case treadmill          // Running·TM / Jogging·TM / Walking·TM
    case seatedMachine      // Stationary Bike / Recumbent Bike / Elliptical
    case rowing             // Rowing erg
    case climber            // Stairmaster / Step Mill
    case interval           // Prowler Sprint / Rope Jumping

    /// Family-tinted accent. Used for eyebrow, recording pill, hero-tile
    /// border, HR ring fg and the Done CTA.
    var accent: Color {
        switch self {
        case .gpsEndurance: return Color(hex: "30C08D")
        case .gpsWheeled:   return Color(hex: "F2812B")
        case .treadmill:    return .gymBroPrimary
        case .seatedMachine: return Color(hex: "7A82F6")
        case .rowing:       return Color(hex: "6B8AD1")
        case .climber:      return Color(hex: "F5B565")
        case .interval:     return Color(hex: "FF453A")
        }
    }

    var eyebrow: String {
        switch self {
        case .gpsEndurance: return "CARDIO · GPS"
        case .gpsWheeled:   return "CARDIO · WHEELED"
        case .treadmill:    return "CARDIO · TREADMILL"
        case .seatedMachine: return "CARDIO · INDOOR"
        case .rowing:       return "CARDIO · ROWING"
        case .climber:      return "CARDIO · CLIMBER"
        case .interval:     return "CARDIO · INTERVAL"
        }
    }

    var iconSystemName: String {
        switch self {
        case .gpsEndurance: return "figure.run"
        case .gpsWheeled:   return "bicycle"
        case .treadmill:    return "figure.run.treadmill"
        case .seatedMachine: return "figure.indoor.cycle"
        case .rowing:       return "figure.rower"
        case .climber:      return "figure.stair.stepper"
        case .interval:     return "bolt.fill"
        }
    }

    var recordingLabel: String {
        switch self {
        case .gpsEndurance, .gpsWheeled: return "RECORDING · GPS LOCKED"
        default: return "RECORDING"
        }
    }

    /// Best-effort family detection from exercise name + equipment. Falls
    /// back to treadmill (coral) for anything unrecognised so the screen
    /// still renders with the brand accent.
    static func detect(name: String, equipment: String) -> CardioFamily {
        let n = name.lowercased()
        let e = equipment.lowercased()

        if n.contains("row") { return .rowing }
        if n.contains("stair") || n.contains("step mill") || n.contains("stepmill") || n.contains("climber") {
            return .climber
        }
        if n.contains("prowler") || n.contains("sprint") || n.contains("interval") ||
            n.contains("jump rope") || n.contains("rope jump") || n.contains("hiit") {
            return .interval
        }
        if n.contains("bike") || n.contains("bicycle") || n.contains("cycling") || n.contains("skat") {
            // Stationary / recumbent → seated machine; outdoor wheeled → GPS wheeled.
            if n.contains("stationary") || n.contains("recumbent") || e.contains("machine") {
                return .seatedMachine
            }
            return .gpsWheeled
        }
        if n.contains("elliptical") { return .seatedMachine }
        if n.contains("treadmill") || n.contains("·tm") || n.contains(" tm") || e.contains("treadmill") {
            return .treadmill
        }
        if n.contains("trail") || n.contains("hike") || n.contains("walk") || n.contains("run") {
            return .gpsEndurance
        }
        // Default to treadmill — keeps the surface on-brand.
        return .treadmill
    }
}

/// A cardio session has three states: idle (target shown), recording
/// (live timer + metrics), and completed (summary card).
enum CardioPhase: Equatable {
    case idle
    case recording
    case completed
}
