//
//  ExercisePerformanceView.swift
//  GymBro
//
//  Performance graph + personal records for an exercise, derived from
//  the existing per-session set history (no new persistence required).
//

import SwiftUI
import Charts

struct ExercisePerformanceView: View {
    let exercise: ActiveSessionExercise
    let previousSessions: [PreviousSessionEntry]

    @State private var selectedMetric: Metric = .estimated1RM
    @State private var selectedRange: TimeRange = .threeMonths

    private let coral = Color.gymBroPrimary
    private let amber = Color(hex: "F5B565")
    private let green = Color(hex: "30C08D")

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartCard
            personalRecordsSection
        }
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            metricTabs

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedMetric.headerLabel)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundColor(.gymBroNeutral400)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(currentValueDisplay)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.gymBroNeutral900)
                            .monospacedDigit()
                        if let unit = selectedMetric.unit {
                            Text(unit)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.gymBroNeutral400)
                        }
                    }
                }
                Spacer()
                if let delta = deltaBadge {
                    Text(delta.text)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(delta.isUp ? green : coral)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((delta.isUp ? green : coral).opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            rangePills

            chartView
                .frame(height: 170)

            legend
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, y: 2)
    }

    private var metricTabs: some View {
        HStack(spacing: 0) {
            ForEach(Metric.allCases) { metric in
                Button {
                    // No withAnimation — the y-axis scale changes dramatically
                    // between metrics (Volume in thousands vs others in tens),
                    // so interpolating between them flings points across the
                    // chart. Snap to the new shape instead.
                    selectedMetric = metric
                } label: {
                    Text(metric.tabLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(selectedMetric == metric ? .gymBroNeutral900 : .gymBroNeutral400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(selectedMetric == metric ? Color.white : .clear)
                                .shadow(color: selectedMetric == metric ? .black.opacity(0.05) : .clear, radius: 1, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.gymBroNeutral100)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var rangePills: some View {
        HStack(spacing: 5) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    // Same reasoning as metric tabs — different ranges produce
                    // different x/y bounds; interpolating points between them
                    // looks like a glitch. Snap.
                    selectedRange = range
                } label: {
                    Text(range.label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.3)
                        .foregroundColor(selectedRange == range ? .white : .gymBroNeutral400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedRange == range ? Color.gymBroNeutral900 : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        let points = visiblePoints
        if points.isEmpty {
            emptyChartState
        } else {
            Chart {
                // Area under the curve
                ForEach(points) { p in
                    AreaMark(x: .value("Date", p.date), y: .value(selectedMetric.tabLabel, p.value))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [coral.opacity(0.25), coral.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                }

                // Line
                ForEach(points) { p in
                    LineMark(x: .value("Date", p.date), y: .value(selectedMetric.tabLabel, p.value))
                        .foregroundStyle(coral)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                }

                // Plain data points
                ForEach(points) { p in
                    PointMark(x: .value("Date", p.date), y: .value(selectedMetric.tabLabel, p.value))
                        .symbolSize(28)
                        .foregroundStyle(coral)
                }

                // PR markers — halo dot. Larger filled coral point with a
                // soft outer glow + tight white ring; reads as "this is
                // special" without screaming about it.
                ForEach(points.filter { $0.isPR }) { p in
                    PointMark(x: .value("Date", p.date), y: .value(selectedMetric.tabLabel, p.value))
                        .symbol {
                            ZStack {
                                Circle()
                                    .fill(coral.opacity(0.18))
                                    .frame(width: 20, height: 20)
                                Circle()
                                    .fill(coral.opacity(0.32))
                                    .frame(width: 14, height: 14)
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.8)
                                    .background(Circle().fill(coral))
                                    .frame(width: 9, height: 9)
                            }
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { value in
                    AxisGridLine().foregroundStyle(Color.gymBroNeutral100)
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.gymBroNeutral400)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.gymBroNeutral100)
                    AxisValueLabel()
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.gymBroNeutral400)
                }
            }
        }
    }

    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(.gymBroNeutral200)
            Text("Log a few sessions to see your trend")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gymBroNeutral400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Circle().fill(coral).frame(width: 8, height: 8)
                Text(selectedMetric.legendLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gymBroNeutral600)
            }
            HStack(spacing: 5) {
                ZStack {
                    Circle().fill(coral.opacity(0.25)).frame(width: 14, height: 14)
                    Circle().fill(coral).frame(width: 7, height: 7)
                }
                Text("PR session")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gymBroNeutral600)
            }
            Spacer()
        }
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personal records")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.gymBroNeutral900)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(personalRecords) { pr in
                    HStack(spacing: 10) {
                        Text(pr.tag)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.7)
                            .foregroundColor(.gymBroNeutral400)
                            .frame(width: 34, alignment: .leading)
                        Text(pr.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gymBroNeutral900)
                        Spacer()
                        Text(pr.value)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gymBroNeutral900)
                            .monospacedDigit()
                        Text(pr.date)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gymBroNeutral400)
                            .frame(width: 46, alignment: .trailing)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    if pr.id != personalRecords.last?.id {
                        Divider()
                            .background(Color.gymBroNeutral100)
                            .padding(.horizontal, 12)
                    }
                }
                if personalRecords.isEmpty {
                    Text("No completed sets yet")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gymBroNeutral400)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gymBroNeutral100, lineWidth: 1)
            )
        }
    }

    // MARK: - Data

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let topSet: (weight: Double, reps: Int)?
        var isPR: Bool = false
    }

    private struct SessionSnapshot {
        let date: Date
        let sets: [(weight: Double, reps: Int)]
    }

    private struct PRItem: Identifiable {
        let id: String
        let tag: String
        let name: String
        let value: String
        let date: String
    }

    /// Combined snapshot of every past session + today (if today has data).
    private var sessions: [SessionSnapshot] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        var snapshots: [SessionSnapshot] = []
        for entry in previousSessions {
            guard let raw = entry.sessionDate else { continue }
            let parsed = isoFormatter.date(from: raw) ?? fallbackFormatter.date(from: raw)
            guard let date = parsed else { continue }
            let pairs: [(Double, Int)] = entry.sets.compactMap { set in
                // Bodyweight sets without a logged weight don't contribute to weight-based metrics.
                guard let weight = set.weight, weight > 0, set.reps > 0 else { return nil }
                return (weight, set.reps)
            }
            if !pairs.isEmpty {
                snapshots.append(SessionSnapshot(date: date, sets: pairs))
            }
        }
        // Today's session — only if completed sets exist with weight + reps.
        let todayPairs: [(Double, Int)] = exercise.sets.compactMap { set in
            guard set.isCompleted, let weight = set.weight, weight > 0, let reps = set.reps, reps > 0 else { return nil }
            return (weight, reps)
        }
        if !todayPairs.isEmpty {
            snapshots.append(SessionSnapshot(date: Date(), sets: todayPairs))
        }
        return snapshots.sorted { $0.date < $1.date }
    }

    /// Apply selected metric across all sessions.
    private var allPoints: [ChartPoint] {
        sessions.map { snapshot in
            let value = selectedMetric.compute(sets: snapshot.sets)
            let top = snapshot.sets.max { lhs, rhs in lhs.weight < rhs.weight }
            return ChartPoint(date: snapshot.date, value: value, topSet: top)
        }
    }

    /// Mark a session as a PR when its metric value exceeds the running max.
    private var pointsWithPRs: [ChartPoint] {
        var maxSoFar: Double = -.infinity
        var out: [ChartPoint] = []
        for point in allPoints {
            var p = point
            if p.value > maxSoFar {
                p.isPR = maxSoFar != -.infinity // first session isn't a "PR" — it's the baseline
                maxSoFar = p.value
            }
            out.append(p)
        }
        return out
    }

    private var visiblePoints: [ChartPoint] {
        guard let cutoff = selectedRange.cutoffDate(from: Date()) else {
            return pointsWithPRs
        }
        return pointsWithPRs.filter { $0.date >= cutoff }
    }

    private var currentValueDisplay: String {
        guard let last = visiblePoints.last else { return "--" }
        return selectedMetric.format(last.value)
    }

    private var deltaBadge: (text: String, isUp: Bool)? {
        let points = visiblePoints
        guard points.count >= 2 else { return nil }
        let first = points.first!.value
        let last = points.last!.value
        let diff = last - first
        guard abs(diff) >= 0.5 else { return nil }
        let isUp = diff > 0
        let arrow = isUp ? "↑" : "↓"
        let magnitude = selectedMetric.formatDelta(abs(diff))
        return ("\(arrow) \(magnitude) · \(selectedRange.shortLabel)", isUp)
    }

    private var xAxisStride: Calendar.Component {
        switch selectedRange {
        case .oneMonth: return .weekOfYear
        case .threeMonths, .sixMonths: return .month
        case .oneYear, .all: return .month
        }
    }

    private var personalRecords: [PRItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        var items: [PRItem] = []

        // Estimated 1RM (Epley)
        if let best = sessions.flatMap({ session in
            session.sets.map { (Metric.epley(weight: $0.weight, reps: $0.reps), session.date, $0) }
        }).max(by: { $0.0 < $1.0 }) {
            items.append(PRItem(
                id: "est1rm",
                tag: "1RM",
                name: "Estimated",
                value: "\(Int(best.0.rounded())) kg",
                date: formatter.string(from: best.1)
            ))
        }

        // Actual 1RM (heaviest single rep)
        if let best = sessions.flatMap({ session in
            session.sets.filter { $0.reps == 1 }.map { (set: $0, date: session.date) }
        }).max(by: { $0.set.weight < $1.set.weight }) {
            items.append(PRItem(
                id: "actual1rm",
                tag: "x1",
                name: "Actual 1RM",
                value: "\(Int(best.set.weight.rounded())) kg",
                date: formatter.string(from: best.date)
            ))
        }

        // 5-rep max
        if let best = sessions.flatMap({ session in
            session.sets.filter { $0.reps == 5 }.map { (set: $0, date: session.date) }
        }).max(by: { $0.set.weight < $1.set.weight }) {
            items.append(PRItem(
                id: "rep5",
                tag: "x5",
                name: "5-rep max",
                value: "\(Int(best.set.weight.rounded())) kg",
                date: formatter.string(from: best.date)
            ))
        }

        // Best session volume
        if let best = sessions.map({ (session: $0, vol: $0.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }) }).max(by: { $0.vol < $1.vol }) {
            items.append(PRItem(
                id: "vol",
                tag: "VOL",
                name: "Best session vol.",
                value: "\(Int(best.vol.rounded())) kg",
                date: formatter.string(from: best.session.date)
            ))
        }

        return items
    }

    // MARK: - Metric

    enum Metric: String, CaseIterable, Identifiable {
        case estimated1RM, topSet, volume, avgWeight

        var id: String { rawValue }

        var tabLabel: String {
            switch self {
            case .estimated1RM: return "Est. 1RM"
            case .topSet: return "Top set"
            case .volume: return "Volume"
            case .avgWeight: return "Avg wt"
            }
        }

        var headerLabel: String {
            switch self {
            case .estimated1RM: return "ESTIMATED 1RM · CURRENT"
            case .topSet: return "TOP SET WEIGHT · LAST"
            case .volume: return "PER-SESSION VOLUME · LAST"
            case .avgWeight: return "AVG WEIGHT · LAST"
            }
        }

        var legendLabel: String {
            switch self {
            case .estimated1RM: return "Estimated 1RM"
            case .topSet: return "Top set"
            case .volume: return "Session volume"
            case .avgWeight: return "Avg weight"
            }
        }

        var unit: String? {
            switch self {
            case .estimated1RM, .topSet, .avgWeight: return "kg"
            case .volume: return "kg"
            }
        }

        func compute(sets: [(weight: Double, reps: Int)]) -> Double {
            switch self {
            case .estimated1RM:
                return sets.map { Self.epley(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            case .topSet:
                return sets.map { $0.weight }.max() ?? 0
            case .volume:
                return sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
            case .avgWeight:
                guard !sets.isEmpty else { return 0 }
                return sets.reduce(0) { $0 + $1.weight } / Double(sets.count)
            }
        }

        func format(_ value: Double) -> String {
            switch self {
            case .volume:
                if value >= 1000 {
                    return String(format: "%.1fk", value / 1000)
                }
                return "\(Int(value.rounded()))"
            default:
                return "\(Int(value.rounded()))"
            }
        }

        func formatDelta(_ value: Double) -> String {
            switch self {
            case .volume:
                if value >= 1000 {
                    return String(format: "%.1fk", value / 1000)
                }
                return "\(Int(value.rounded()))"
            default:
                return "\(Int(value.rounded())) kg"
            }
        }

        /// Epley formula — single-rep equivalent of a multi-rep set.
        static func epley(weight: Double, reps: Int) -> Double {
            guard reps > 0 else { return weight }
            if reps == 1 { return weight }
            return weight * (1.0 + Double(reps) / 30.0)
        }
    }

    // MARK: - Range

    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth, threeMonths, sixMonths, oneYear, all

        var id: String { rawValue }

        var label: String {
            switch self {
            case .oneMonth: return "1M"
            case .threeMonths: return "3M"
            case .sixMonths: return "6M"
            case .oneYear: return "1Y"
            case .all: return "All"
            }
        }

        var shortLabel: String {
            switch self {
            case .oneMonth: return "1mo"
            case .threeMonths: return "3mo"
            case .sixMonths: return "6mo"
            case .oneYear: return "1y"
            case .all: return "all"
            }
        }

        func cutoffDate(from now: Date) -> Date? {
            let cal = Calendar.current
            switch self {
            case .oneMonth: return cal.date(byAdding: .month, value: -1, to: now)
            case .threeMonths: return cal.date(byAdding: .month, value: -3, to: now)
            case .sixMonths: return cal.date(byAdding: .month, value: -6, to: now)
            case .oneYear: return cal.date(byAdding: .year, value: -1, to: now)
            case .all: return nil
            }
        }
    }
}
