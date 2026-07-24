//
//  WeekCalendarCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-13.
//

import SwiftUI

struct WeekCalendarCard: View {

    // MARK: - Constants

    // Locale-aware single-letter day symbols. veryShortWeekdaySymbols is
    // Sunday-first; the week strip is Monday-first, so rotate by one.
    private let weekDayLetters: [String] = {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }()
    private let monthGridDayLetters = Calendar.current.veryShortWeekdaySymbols
    private let mutedTextColor = Color(hex: "A1A1A1")
    private let dayNumberColor = Color(hex: "525252")
    private let completedColor = Color(hex: "30C08D")
    private let borderColor = Color.gymBroNeutral100
    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)
    private let calendar = Calendar.current

    // MARK: - Data

    /// Indices of completed workout days for current week (0 = Monday)
    var completedDayIndices: Set<Int> = []

    /// Set of dates that have completed sessions (for month view)
    var completedDates: Set<Date> = []

    /// Currently selected date (nil = no selection / today)
    @Binding var selectedDate: Date?

    /// Callback when a completed day is tapped
    var onDayTapped: ((Date) -> Void)?

    /// Callback when selection is cleared (tap today or tap selected again)
    var onSelectionCleared: (() -> Void)?

    /// Fires when the user navigates to a different month via the
    /// chevron arrows. Parent should fetch completed dates for that
    /// month so the grid lights up the right days.
    var onMonthChanged: ((Date) -> Void)?

    // MARK: - Internal State

    @State private var isExpanded: Bool = false
    @State private var displayedMonth: Date = Date()

    // MARK: - Computed Properties

    private var today: Date { Date() }

    private var currentWeekDates: [Date] {
        let todayDate = today
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: todayDate)
        components.weekday = 2 // Monday
        guard let monday = calendar.date(from: components) else { return [] }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            weekStripSection

            if isExpanded {
                expandedSection
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 17)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.03),
            radius: 10,
            x: 0,
            y: 4
        )
        .clipped()
    }

    // MARK: - Week Strip Section

    private var weekStripSection: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    weekDayColumn(index: index)
                        .frame(maxWidth: .infinity)
                }
            }

            chevronButton
                .padding(.leading, 4)
        }
        .frame(height: 64)
    }

    // MARK: - Week Day Column

    @ViewBuilder
    private func weekDayColumn(index: Int) -> some View {
        let date = index < currentWeekDates.count ? currentWeekDates[index] : nil
        let dayNum = date.map { calendar.component(.day, from: $0) } ?? 0
        let isCompleted = completedDayIndices.contains(index)
        let isTodayDate = date.map { isSameDay($0, today) } ?? false
        let isSelected = date.flatMap { d in selectedDate.map { isSameDay(d, $0) } } ?? false

        VStack(spacing: 8) {
            Text(weekDayLetters[index])
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundColor(mutedTextColor)
                .textCase(.uppercase)

            Button {
                guard let date else { return }
                handleDayTap(date: date, isCompleted: isCompleted, isToday: isTodayDate)
            } label: {
                weekDayCell(
                    dayNumber: dayNum,
                    isCompleted: isCompleted,
                    isToday: isTodayDate,
                    isSelected: isSelected
                )
            }
            .buttonStyle(.plain)
            .disabled(!isCompleted && !isTodayDate)
        }
    }

    @ViewBuilder
    private func weekDayCell(
        dayNumber: Int,
        isCompleted: Bool,
        isToday: Bool,
        isSelected: Bool
    ) -> some View {
        ZStack {
            if isSelected && isCompleted {
                // Selected completed day: red/coral filled circle with white number
                Circle()
                    .fill(Color.gymBroPrimary)
                    .frame(width: 32, height: 32)
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else if isToday {
                // Today: dark filled circle with white number
                Circle()
                    .fill(Color.gymBroNeutral900)
                    .frame(width: 32, height: 32)
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else if isCompleted {
                // Completed (not selected): green tinted circle with checkmark
                Circle()
                    .fill(completedColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(completedColor)
            } else {
                // Future/uncompleted: plain day number
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(mutedTextColor)
                    .frame(width: 32, height: 32)
            }
        }
        .frame(width: 32, height: 32)
    }

    // MARK: - Chevron Button

    private var chevronButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
            analytics.track(isExpanded ? "calendar_expanded" : "calendar_collapsed", properties: [:])
        } label: {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(dayNumberColor)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Section

    private var expandedSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.top, 8)

            monthNavigationHeader

            monthGrid

            legendRow
        }
    }

    // MARK: - Month Navigation Header

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                let next = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                withAnimation(.easeInOut(duration: 0.3)) {
                    displayedMonth = next
                }
                onMonthChanged?(next)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(dayNumberColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthYearString(from: displayedMonth))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            Spacer()

            Button {
                let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                withAnimation(.easeInOut(duration: 0.3)) {
                    displayedMonth = next
                }
                onMonthChanged?(next)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(dayNumberColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Month Grid

    private var monthGrid: some View {
        let gridData = monthGridData()

        return VStack(spacing: 8) {
            // Day-of-week headers (Sun-Sat)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(monthGridDayLetters[index])
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.6)
                        .foregroundColor(mutedTextColor)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells in rows of 7
            ForEach(0..<gridData.count / 7, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let cell = gridData[cellIndex]
                        monthDayCell(cell: cell)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func monthDayCell(cell: MonthDayCell) -> some View {
        if let date = cell.date, cell.isInCurrentMonth {
            let dayNum = calendar.component(.day, from: date)
            let isCompleted = isDateCompleted(date)
            let isTodayDate = isSameDay(date, today)
            let isSelected = selectedDate.map { isSameDay(date, $0) } ?? false

            Button {
                handleDayTap(date: date, isCompleted: isCompleted, isToday: isTodayDate)
            } label: {
                ZStack {
                    if isSelected && isCompleted {
                        Circle()
                            .fill(Color.gymBroPrimary)
                            .frame(width: 32, height: 32)
                        Text("\(dayNum)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else if isTodayDate {
                        Circle()
                            .fill(Color.gymBroNeutral900)
                            .frame(width: 32, height: 32)
                        Text("\(dayNum)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else if isCompleted {
                        Circle()
                            .fill(completedColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text("\(dayNum)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(completedColor)
                    } else {
                        Text("\(dayNum)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(dayNumberColor)
                    }
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(!isCompleted && !isTodayDate)
        } else {
            // Empty cell for days outside the month
            Color.clear
                .frame(width: 36, height: 36)
        }
    }

    // MARK: - Legend Row

    private var legendRow: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.gymBroNeutral900)
                    .frame(width: 8, height: 8)
                Text("Today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(dayNumberColor)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(completedColor)
                    .frame(width: 8, height: 8)
                Text("Completed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(dayNumberColor)
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Tap Handling

    private func handleDayTap(date: Date, isCompleted: Bool, isToday: Bool) {
        if isToday {
            // Tapping today: if a past day was selected, clear selection
            if selectedDate != nil {
                selectedDate = nil
                onSelectionCleared?()
            }
            return
        }

        guard isCompleted else { return }

        if let currentSelection = selectedDate, isSameDay(currentSelection, date) {
            // Tapping already selected day: deselect
            selectedDate = nil
            onSelectionCleared?()
        } else {
            // Tapping a different completed day: select it
            selectedDate = date
            let formatter = ISO8601DateFormatter()
            analytics.track("calendar_day_changed", properties: ["date": formatter.string(from: date)])
            onDayTapped?(date)
        }
    }

    // MARK: - Date Helpers

    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        calendar.isDate(date1, inSameDayAs: date2)
    }

    private func isDateCompleted(_ date: Date) -> Bool {
        // Check completedDates set (compare by day)
        let dateIsInCompletedDates = completedDates.contains { isSameDay($0, date) }
        if dateIsInCompletedDates { return true }

        // Also check completedDayIndices for current week
        if let weekIndex = currentWeekIndex(for: date) {
            return completedDayIndices.contains(weekIndex)
        }

        return false
    }

    /// Returns the Monday-based index (0=Mon, 6=Sun) if the date falls in the current week, nil otherwise
    private func currentWeekIndex(for date: Date) -> Int? {
        guard let matchIndex = currentWeekDates.firstIndex(where: { isSameDay($0, date) }) else {
            return nil
        }
        return matchIndex
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Month Grid Data

    private struct MonthDayCell {
        let date: Date?
        let isInCurrentMonth: Bool
    }

    private func monthGridData() -> [MonthDayCell] {
        let year = calendar.component(.year, from: displayedMonth)
        let month = calendar.component(.month, from: displayedMonth)

        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let daysInMonth = range.count

        // weekday of first day: 1=Sun, 2=Mon, ..., 7=Sat
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)

        // Leading empty cells (grid starts on Sunday, index 0 = Sunday)
        // firstWeekday 1 (Sun) -> 0 leading empties
        // firstWeekday 2 (Mon) -> 1 leading empty
        // ...
        // firstWeekday 7 (Sat) -> 6 leading empties
        let leadingEmpties = firstWeekday - 1

        var cells: [MonthDayCell] = []

        // Leading empties
        for _ in 0..<leadingEmpties {
            cells.append(MonthDayCell(date: nil, isInCurrentMonth: false))
        }

        // Actual days of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                cells.append(MonthDayCell(date: date, isInCurrentMonth: true))
            }
        }

        // Trailing empties to complete the last row
        let remainder = cells.count % 7
        if remainder > 0 {
            let trailingEmpties = 7 - remainder
            for _ in 0..<trailingEmpties {
                cells.append(MonthDayCell(date: nil, isInCurrentMonth: false))
            }
        }

        return cells
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedDate: Date? = nil

    let cal = Calendar.current
    let today = Date()

    // Simulate some completed dates
    let completedDates: Set<Date> = {
        var dates = Set<Date>()
        for offset in [-5, -3, -1, -7, -10] {
            if let d = cal.date(byAdding: .day, value: offset, to: today) {
                dates.insert(d)
            }
        }
        return dates
    }()

    ScrollView {
        VStack(spacing: 20) {
            WeekCalendarCard(
                completedDayIndices: [0, 2, 4],
                completedDates: completedDates,
                selectedDate: $selectedDate,
                onDayTapped: { date in
                    print("Tapped: \(date)")
                },
                onSelectionCleared: {
                    print("Selection cleared")
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
    }
    .background(Color.gymBroBackground)
}
