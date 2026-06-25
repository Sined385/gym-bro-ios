//
//  ProfileOverviewComponents.swift
//  GymBro
//
//  Building blocks for the redesigned community profile Overview tab:
//  the tab bar, strength (1RM) card, consistency card, and muscle-focus chips.
//

import SwiftUI

// MARK: - Tab Bar

struct ProfileTabBar: View {
    @Binding var selected: ProfileTab
    /// Optional count badge per tab (nil = no badge).
    let counts: [ProfileTab: Int]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.gymBroBorderLight)
                .frame(height: 1)
        }
    }

    private func tabButton(_ tab: ProfileTab) -> some View {
        let isSelected = selected == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selected = tab }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isSelected ? .gymBroNeutral900 : .gymBroNeutral400)
                    if let c = counts[tab], c > 0 {
                        Text("\(c)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isSelected ? .gymBroPrimary : .gymBroNeutral400)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(isSelected
                                    ? Color.gymBroPrimary.opacity(0.12)
                                    : Color.gymBroNeutral100)
                            )
                    }
                }
                Rectangle()
                    .fill(isSelected ? Color.gymBroPrimary : .clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Strength (1-rep max) card

struct StrengthStatCard: View {
    let oneRepMax: OneRepMax
    let bodyWeightKg: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Strength · 1-rep max")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
            } icon: {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "F5A623"))
            }

            HStack(spacing: 0) {
                liftColumn("BENCH", value: oneRepMax.bench)
                divider
                liftColumn("SQUAT", value: oneRepMax.squat)
                divider
                liftColumn("DEADLIFT", value: oneRepMax.deadlift)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymBroCardBackground)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gymBroBorderLight, lineWidth: 1))
        .cornerRadius(18)
    }

    private var divider: some View {
        Rectangle().fill(Color.gymBroBorderLight).frame(width: 1, height: 44)
    }

    private func liftColumn(_ name: String, value: Int?) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.gymBroNeutral400)
            if let value {
                (Text("\(value)").font(.system(size: 22, weight: .bold))
                 + Text(" kg").font(.system(size: 10, weight: .bold)).foregroundColor(.gymBroNeutral400))
                    .foregroundColor(.gymBroNeutral900)
                if let ratio = bodyWeightRatio(value) {
                    Text(ratio)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gymBroPrimary)
                } else {
                    Text(" ").font(.system(size: 9, weight: .bold))
                }
            } else {
                Text("—").font(.system(size: 22, weight: .bold)).foregroundColor(.gymBroNeutral400)
                Text(" ").font(.system(size: 9, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func bodyWeightRatio(_ oneRm: Int) -> String? {
        guard let bw = bodyWeightKg, bw > 0 else { return nil }
        return String(format: "%.1f× BW", Double(oneRm) / bw)
    }
}

// MARK: - Consistency card

struct ConsistencyCard: View {
    let weekStreak: Int
    let sessionsPerWeek: Double
    let allTimeSessions: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Consistency")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
            } icon: {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.gymBroPrimary)
            }

            HStack(spacing: 8) {
                cell(label: "week streak") {
                    HStack(spacing: 3) {
                        Text("\(weekStreak)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.gymBroPrimary)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gymBroPrimary)
                    }
                }
                cell(label: "sessions / wk") {
                    Text(sessionsPerWeek == sessionsPerWeek.rounded() ? "\(Int(sessionsPerWeek))" : String(format: "%.1f", sessionsPerWeek))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                }
                cell(label: "all-time") {
                    Text("\(allTimeSessions)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymBroCardBackground)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gymBroBorderLight, lineWidth: 1))
        .cornerRadius(18)
    }

    private func cell<V: View>(label: String, @ViewBuilder value: () -> V) -> some View {
        VStack(spacing: 2) {
            value()
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.gymBroTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.gymBroNeutral100)
        .cornerRadius(12)
    }
}

// MARK: - Muscle focus chips

struct MuscleFocusChips: View {
    let muscles: [String]

    private static let dotColors: [Color] = [
        .gymBroPrimary, Color(hex: "7A82F6"), Color(hex: "F5A623"), Color(hex: "30C08D"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAINS MOST")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.9)
                .foregroundColor(.gymBroNeutral400)

            FlexibleChips(items: Array(muscles.prefix(4).enumerated())) { pair in
                let (index, muscle) = pair
                HStack(spacing: 5) {
                    Circle()
                        .fill(Self.dotColors[index % Self.dotColors.count])
                        .frame(width: 7, height: 7)
                    Text(muscle.capitalized)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gymBroNeutral600)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Color.gymBroNeutral100)
                .cornerRadius(10)
            }
        }
    }
}

/// Minimal wrapping HStack for a small, fixed set of chips.
private struct FlexibleChips<Item, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                content(item)
            }
            Spacer(minLength: 0)
        }
    }
}
