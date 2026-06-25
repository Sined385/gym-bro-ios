//
//  ProfileComparisonCard.swift
//  GymBro
//
//  "You vs <name>" head-to-head. The comparable metrics are picked dynamically
//  by the server (shared lifts + activity stats); an AI analysis is written
//  from those metrics. Premium-gated — free users see a blurred teaser.
//

import SwiftUI

struct ProfileComparisonCard: View {
    let comparison: HeadToHead?
    let isLoading: Bool
    let isPremium: Bool
    let otherName: String
    let onUpgrade: () -> Void

    @State private var expanded = false
    private let purple = Color(hex: "7A82F6")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW YOU TWO STACK UP")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.9)
                .foregroundColor(.gymBroNeutral400)

            if !isPremium {
                lockedTeaser
            } else {
                loadedCard
            }
        }
    }

    private var loadedCard: some View {
        let metrics = comparison?.metrics ?? []
        let analysis = comparison?.analysis
        return VStack(alignment: .leading, spacing: 11) {
            header
            if isLoading && comparison == nil {
                HStack { Spacer(); ProgressView().tint(purple); Spacer() }.padding(.vertical, 16)
            } else if metrics.isEmpty && analysis == nil {
                Text("Not enough shared workout data to compare yet — once you've both logged the same lifts, they'll show up here.")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.gymBroNeutral600)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let verdict = analysis?.verdict {
                    Text(verdict)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.gymBroNeutral600)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !metrics.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(metrics) { metricRow($0) }
                    }
                }
                if expanded, let analysis { expandedAnalysis(analysis) }
                if hasBreakdown(analysis) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 5) {
                            Text(expanded ? "Hide breakdown" : "See full breakdown")
                            Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(purple)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .overlay(alignment: .top) { Rectangle().fill(purple.opacity(0.18)).frame(height: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(13)
        .background(comparisonBackground)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(purple.opacity(0.28), lineWidth: 1))
        .cornerRadius(18)
    }

    private func hasBreakdown(_ a: ComparisonAnalysis?) -> Bool {
        guard let a else { return false }
        return a.yourEdge != nil || a.theirEdge != nil || a.takeaway != nil
    }

    private var header: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 9)
                .fill(LinearGradient(colors: [purple, Color(hex: "5A63D8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "sparkles").font(.system(size: 13)).foregroundColor(.white))
            VStack(alignment: .leading, spacing: 1) {
                Text("You vs \(firstName(otherName))")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.gymBroNeutral900)
                Text("AI head-to-head").font(.system(size: 10, weight: .semibold)).foregroundColor(purple)
            }
            Spacer()
        }
    }

    private func metricRow(_ metric: ComparisonMetric) -> some View {
        let m = metric.currentValue
        let t = metric.otherValue
        let total = max(m + t, 0.0001)
        let meFrac = (m + t == 0) ? 0.5 : m / total
        let higherBetter = metric.higherIsBetter ?? true
        let meWins = higherBetter ? (m >= t) : (m <= t)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metric.label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(.gymBroNeutral400)
                Spacer()
                Text(meWins ? "You" : firstName(otherName))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(meWins ? .gymBroPrimary : purple)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7).fill(Color.gymBroNeutral100)
                    HStack(spacing: 0) {
                        ZStack(alignment: .leading) {
                            LinearGradient(colors: [Color.gymBroPrimary.opacity(0.85), Color.gymBroPrimary], startPoint: .leading, endPoint: .trailing)
                            Text(format(m, unit: metric.unit)).font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.leading, 7)
                        }
                        .frame(width: geo.size.width * meFrac)
                        ZStack(alignment: .trailing) {
                            LinearGradient(colors: [purple.opacity(0.55), purple.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                            Text(format(t, unit: metric.unit)).font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.trailing, 7)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }
            .frame(height: 22)
        }
    }

    private func expandedAnalysis(_ a: ComparisonAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if a.yourEdge != nil || a.theirEdge != nil {
                HStack(spacing: 8) {
                    if let e = a.yourEdge { edge("YOUR EDGE", e, tint: .gymBroPrimary) }
                    if let e = a.theirEdge { edge("\(firstName(otherName).uppercased())'S EDGE", e, tint: purple) }
                }
            }
            if let takeaway = a.takeaway {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TAKEAWAY").font(.system(size: 8.5, weight: .bold)).tracking(0.9).foregroundColor(Color(hex: "30C08D"))
                    Text(takeaway).font(.system(size: 12, weight: .semibold)).foregroundColor(.gymBroNeutral600)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "30C08D").opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "30C08D").opacity(0.28), lineWidth: 1))
                .cornerRadius(12)
            }
        }
        .padding(.top, 4)
        .overlay(alignment: .top) { Rectangle().fill(purple.opacity(0.18)).frame(height: 1) }
    }

    private func edge(_ label: String, _ text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 8.5, weight: .bold)).foregroundColor(tint)
            Text(text).font(.system(size: 11, weight: .semibold)).foregroundColor(.gymBroNeutral600)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(tint.opacity(0.2), lineWidth: 1))
        .cornerRadius(11)
    }

    private var lockedTeaser: some View {
        ZStack {
            VStack(spacing: 9) {
                header
                VStack(spacing: 9) { teaserBar(0.42); teaserBar(0.54); teaserBar(0.48) }
            }
            .padding(13)
            .blur(radius: 6).opacity(0.55).allowsHitTesting(false)

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(LinearGradient(colors: [Color(hex: "F5A623"), .gymBroPrimary], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                    .overlay(Image(systemName: "lock.fill").font(.system(size: 18)).foregroundColor(.white))
                Text("Unlock AI comparison").font(.system(size: 15, weight: .bold)).foregroundColor(.gymBroNeutral900)
                Text("See how you stack up against \(firstName(otherName)) on the lifts you both train, and what to steal from their routine.")
                    .font(.system(size: 11.5, weight: .semibold)).foregroundColor(.gymBroNeutral600)
                    .multilineTextAlignment(.center).padding(.horizontal, 12)
                Button(action: onUpgrade) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 12))
                        Text("Go Premium").font(.system(size: 12.5, weight: .bold))
                    }
                    .foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 9)
                    .background(Color(hex: "2D3240")).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .background(comparisonBackground)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gymBroBorderLight, lineWidth: 1))
        .cornerRadius(18)
    }

    private func teaserBar(_ frac: CGFloat) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(Color.gymBroNeutral100).frame(width: 54, height: 9)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7).fill(Color.gymBroNeutral100)
                    HStack(spacing: 0) {
                        Color.gymBroPrimary.opacity(0.85).frame(width: geo.size.width * frac)
                        purple.opacity(0.7)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }
            .frame(height: 22)
        }
    }

    private func format(_ value: Double, unit: String?) -> String {
        guard value > 0 else { return "" }
        let num = value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
        if let unit, !unit.isEmpty { return "\(num) \(unit)" }
        return num
    }

    private var comparisonBackground: some View {
        LinearGradient(colors: [purple.opacity(0.10), Color.gymBroPrimary.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .background(Color.gymBroCardBackground)
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
