//
//  CardioMetricsView.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-22.
//
//  The reusable cardio metric body shared by every CardioFamily. The
//  spine (CardioWorkoutView) owns timer state + accent; this view
//  renders the idle Start hero, the recording hero (calories + elapsed),
//  the burn-rate tile, the no-HR strip and the calories-per-minute
//  ribbon, and the completed summary.
//
//  Generalized from the original SeatedMachineMetricsView: the only
//  family-specific input is the MET factor, which now comes from a
//  CardioMetricSpec instead of a hard-coded constant. All families plug
//  in through this one view.
//

import SwiftUI

struct CardioMetricsView: View {
    let elapsedSeconds: Int
    let phase: CardioPhase
    let isPaused: Bool
    let targetSeconds: Int
    /// User body weight in kg, when available. When nil we hide the
    /// calories number and the ribbon — no fabricated kcal.
    let bodyWeightKg: Double?
    /// Family accent (passed in so this view stays family-agnostic).
    let accent: Color
    /// Family metric configuration (MET factor, completion metrics).
    let spec: CardioMetricSpec
    /// Effective target pace (km/h) to display — the set's coach/user
    /// value when present, otherwise the family heuristic. Nil hides the
    /// speed entirely. Resolved by the spine, not read off `spec`.
    let targetSpeedKmh: Double?
    /// Logged distance (metres) once the set is completed — drives the
    /// actual average speed in the completed summary. Nil while idle /
    /// recording or when the user skipped distance entry.
    let distanceMeters: Int?
    /// Called when the user taps the idle hero card. Tells the spine to
    /// kick the session manager's startCardio.
    let onStart: () -> Void

    private var met: Double { spec.met }
    private let textSec = Color(hex: "717182")
    private let border = Color(hex: "F0F0F2")
    private let n200 = Color(hex: "E5E5E5")
    private let n400 = Color(hex: "A1A1A1")
    private let n600 = Color(hex: "525252")
    private let green = Color(hex: "30C08D")

    var body: some View {
        VStack(spacing: 10) {
            switch phase {
            case .idle:
                idleStartHero
                noHRStrip
            case .recording:
                // One calories surface (the hero) + the target-speed
                // guidance tile. The old kcal/min tile + kcal/min ribbon
                // were a second & third calories readout — removed.
                heroTile
                if targetSpeedKmh != nil {
                    targetSpeedTile
                }
                noHRStrip
            case .completed:
                completedHero
                noHRStrip
            }
        }
    }

    // MARK: - Idle Start CTA (replaces the calories hero before recording)

    /// The "Start Cardio" surface lives where the calories hero will
    /// sit during recording. Same gradient, same paddings — but the
    /// content is a tap target with a play icon, an action label, and
    /// the planned duration. This is the screen's only Start
    /// affordance; no duplicate bottom button.
    private var idleStartHero: some View {
        Button(action: onStart) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent)
                        .frame(width: 56, height: 56)
                        .shadow(color: accent.opacity(0.35), radius: 12, y: 6)
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("START CARDIO")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.9)
                        .foregroundColor(accent)
                    Text(formatTargetLabel(targetSeconds))
                        .font(.system(size: 22, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundColor(.gymBroNeutral900)
                    Text("Tap to begin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textSec)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [accent.opacity(0.10), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func formatTargetLabel(_ s: Int) -> String {
        let m = max(1, s / 60)
        let duration = m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m) min"
        if let kmh = targetSpeedKmh {
            return "\(duration) · \(formatSpeed(kmh)) km/h target"
        }
        return "\(duration) target"
    }

    // MARK: - Completed summary hero

    /// After Done: green check + final duration + the calories tally.
    /// Lives where the calories hero lives during recording so the
    /// transition is in-place.
    private var completedHero: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(green)
                    .frame(width: 56, height: 56)
                    .shadow(color: green.opacity(0.35), radius: 12, y: 6)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("COMPLETED")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.9)
                    .foregroundColor(green)
                Text(elapsedColon)
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-1)
                    .foregroundColor(.gymBroNeutral900)
                    .monospacedDigit()
                Text(completedSubtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textSec)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [green.opacity(0.10), .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(green.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
    }

    // MARK: - Hero tile (calories burned + elapsed)

    private var heroTile: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CALORIES BURNED")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.7)
                    .foregroundColor(accent)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(caloriesString)
                        .font(.system(size: 46, weight: .heavy))
                        .tracking(-2)
                        .foregroundColor(accent)
                        .monospacedDigit()
                    Text(" kcal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accent.opacity(0.6))
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                Text("ELAPSED")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.7)
                    .foregroundColor(textSec)
                Text(elapsedColon)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.gymBroNeutral900)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.10), .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
    }

    // MARK: - Target-speed tile

    /// Guidance tile: the pace to set the machine to. Treadmill can't
    /// measure live speed (distance is entered at the end), so this is a
    /// static target the user dials in — the actual average speed is
    /// shown in the completed summary once distance is known.
    @ViewBuilder
    private var targetSpeedTile: some View {
        if let kmh = targetSpeedKmh {
            tile {
                Text("TARGET SPEED")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.7)
                    .foregroundColor(textSec)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(formatSpeed(kmh))
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundColor(.gymBroNeutral900)
                        .monospacedDigit()
                    Text(" km/h")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(textSec)
                }
                Text("Set the machine to this pace")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(n400)
            }
        }
    }

    @ViewBuilder
    private func tile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
    }

    // MARK: - No-HR strip

    private var noHRStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(n400)
            VStack(alignment: .leading, spacing: 1) {
                Text("Heart rate hidden")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(n600)
                Text("Connect a watch or strap to see live pulse & zones")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(n400)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(n200, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }

    // MARK: - Derived values

    private var elapsedColon: String {
        let s = max(0, elapsedSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    /// Total calories burned using MET formula:
    ///   kcal = MET × bodyWeightKg × (elapsedSeconds / 3600)
    /// nil when body weight isn't known (we don't fabricate).
    private var caloriesValue: Double? {
        guard let kg = bodyWeightKg, kg > 0 else { return nil }
        return met * kg * (Double(elapsedSeconds) / 3600.0)
    }

    private var caloriesString: String {
        guard let v = caloriesValue else { return "—" }
        return "\(Int(v.rounded()))"
    }

    /// "5.0" / "12" — drops the decimal for whole numbers ≥ 10.
    private func formatSpeed(_ kmh: Double) -> String {
        kmh >= 10 ? String(format: "%.0f", kmh) : String(format: "%.1f", kmh)
    }

    /// Completed summary line: the real numbers from this session —
    /// calories (when body weight is known), distance and average speed
    /// (when distance was entered). Falls back to a friendly default when
    /// nothing quantitative is available.
    private var completedSubtitle: String {
        var parts: [String] = []
        if let kcal = caloriesValue, kcal > 0 {
            parts.append("\(Int(kcal.rounded())) kcal")
        }
        if let meters = distanceMeters, meters > 0 {
            let km = Double(meters) / 1000.0
            parts.append(String(format: km >= 10 ? "%.1f km" : "%.2f km", km))
        }
        if let kmh = actualSpeedKmh {
            parts.append("\(formatSpeed(kmh)) km/h avg")
        }
        return parts.isEmpty ? "Saved · ready for the next exercise" : parts.joined(separator: " · ")
    }

    /// Actual average speed (km/h) once distance is logged. Nil while the
    /// distance is unknown or the elapsed time is zero.
    private var actualSpeedKmh: Double? {
        guard let meters = distanceMeters, meters > 0, elapsedSeconds > 0 else { return nil }
        return (Double(meters) / 1000.0) / (Double(elapsedSeconds) / 3600.0)
    }
}
