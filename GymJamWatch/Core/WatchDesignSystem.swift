//
//  WatchDesignSystem.swift
//  GymJamWatch
//
//  Watch-adapted design tokens: colors, typography, haptics.
//

import SwiftUI
import WatchKit

// MARK: - Watch Colors

enum WatchColors {
    static let primary = GymJamColors.primary
    static let primaryDark = GymJamColors.primaryDark
    static let purple = GymJamColors.purple
    static let green = GymJamColors.green
    static let yellow = GymJamColors.yellow
    static let textSecondary = GymJamColors.textSecondary
    static let cardBackground = GymJamColors.cardBackground
    static let surface = Color(white: 0.15)
}

// MARK: - Watch Typography

enum WatchTypography {
    /// Large display: timer, rest countdown — 34pt bold monospaced
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .default).monospacedDigit()
    /// Numeric stat: weight, reps, BPM — 24pt bold monospaced
    static let numeric = Font.system(size: 24, weight: .bold, design: .default).monospacedDigit()
    /// Section title: exercise name — 17pt semibold
    static let sectionTitle = Font.system(size: 17, weight: .semibold)
    /// Body: set info — 15pt semibold
    static let body = Font.system(size: 15, weight: .semibold)
    /// Body regular — 15pt regular
    static let bodyRegular = Font.system(size: 15, weight: .regular)
    /// Caption: units, secondary — 13pt regular
    static let caption = Font.system(size: 13, weight: .regular)
    /// Micro: timestamps, minimal — 11pt regular
    static let micro = Font.system(size: 11, weight: .regular)
    /// Button text — 15pt semibold
    static let button = Font.system(size: 15, weight: .semibold)
}

// MARK: - Haptics

enum WatchHaptics {
    static func setCompleted() {
        WKInterfaceDevice.current().play(.success)
    }

    static func restTimerFinished() {
        WKInterfaceDevice.current().play(.notification)
    }

    static func restTimer30sWarning() {
        WKInterfaceDevice.current().play(.click)
    }

    static func digitalCrownTick() {
        WKInterfaceDevice.current().play(.click)
    }

    static func workoutStarted() {
        WKInterfaceDevice.current().play(.start)
    }

    static func workoutCompleted() {
        WKInterfaceDevice.current().play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WKInterfaceDevice.current().play(.success)
        }
    }

    static func error() {
        WKInterfaceDevice.current().play(.failure)
    }
}

// MARK: - Watch Button Styles

struct WatchPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WatchTypography.button)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(WatchColors.primary)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct WatchOutlineButtonStyle: ButtonStyle {
    var color: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WatchTypography.button)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(color.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Heart Rate Zone

enum HeartRateZone: String {
    case rest = "Rest"
    case fatBurn = "Fat Burn"
    case cardio = "Cardio"
    case peak = "Peak"

    var color: Color {
        switch self {
        case .rest: return WatchColors.green
        case .fatBurn: return WatchColors.yellow
        case .cardio: return .orange
        case .peak: return .red
        }
    }

    static func zone(for bpm: Double, age: Int = 30) -> HeartRateZone {
        let maxHR = Double(220 - age)
        let percentage = bpm / maxHR
        switch percentage {
        case ..<0.5: return .rest
        case 0.5..<0.7: return .fatBurn
        case 0.7..<0.85: return .cardio
        default: return .peak
        }
    }
}
