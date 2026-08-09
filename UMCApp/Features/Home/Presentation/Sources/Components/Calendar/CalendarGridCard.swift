//
//  CalendarGridCard.swift
//  HomePresentation
//
//  Created by euijjang97 on 8/9/26.
//

import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 표시 월 전체를 7열 달력 그리드로 보여주는 카드.
///
/// 인접 월의 날짜는 자리만 채워 주 단위 정렬을 유지하고, 일정이 있는 날짜에는 점을 표시한다.
struct CalendarGridCard: View, Equatable {

    // MARK: - Property

    @Binding var selectedDate: Date
    @Binding var month: Date
    let scheduledDates: Set<Date>

    fileprivate enum Constants {
        static let padding: CGFloat = 24
        static let weekdayCount = 7
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectedDate == rhs.selectedDate &&
        lhs.month == rhs.month &&
        lhs.scheduledDates == rhs.scheduledDates
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing24) {
            weekdayHeader
            dateGrid
        }
        .padding(Constants.padding)
        .glassEffect(
            .regular,
            in: .rect(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: .zero) {
            ForEach(Date.weekDaySymbols(), id: \.self) { symbol in
                Text(symbol)
                    .appFont(.subheadline, weight: .medium, color: .grey400)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Date Grid

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: DefaultSpacing.spacing8),
            count: Constants.weekdayCount
        )
    }

    private var dateGrid: some View {
        LazyVGrid(columns: columns, spacing: DefaultSpacing.spacing8) {
            ForEach(adjustedDates, id: \.self) { date in
                if Calendar.kstGregorian.isDate(date, equalTo: month, toGranularity: .month) {
                    DateCell(
                        date: date,
                        isSelected: date.isSameDay(selectedDate),
                        hasSchedule: hasSchedule(date),
                        isToday: date.isSameDay(.now)
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: DefaultConstant.animationTime)) {
                            selectedDate = date
                        }
                    }
                } else {
                    Color.clear
                }
            }
        }
    }

    // MARK: - Function

    /// 표시 월의 날짜 앞/뒤에 인접 월의 날짜를 채워 7일 단위 그리드를 완성한다.
    private var adjustedDates: [Date] {
        let calendar = Calendar.kstGregorian
        let datesInMonth = month.datesInMonth()
        guard
            let firstDate = datesInMonth.first,
            let lastDate = datesInMonth.last
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDate)
        let lastWeekday = calendar.component(.weekday, from: lastDate)

        var dates: [Date] = []
        let emptyDaysBefore = firstWeekday - 1
        for offset in 0..<emptyDaysBefore {
            let value = -(emptyDaysBefore - offset)
            if let date = calendar.date(byAdding: .day, value: value, to: firstDate) {
                dates.append(date)
            }
        }

        dates.append(contentsOf: datesInMonth)

        let emptyDaysAfter = Constants.weekdayCount - lastWeekday
        if emptyDaysAfter > 0 {
            for offset in 1...emptyDaysAfter {
                if let date = calendar.date(byAdding: .day, value: offset, to: lastDate) {
                    dates.append(date)
                }
            }
        }

        return dates
    }

    private func hasSchedule(_ date: Date) -> Bool {
        scheduledDates.contains { $0.isSameDay(date) }
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var selectedDate: Date = .now
    @Previewable @State var month: Date = .now

    CalendarGridCard(
        selectedDate: $selectedDate,
        month: $month,
        scheduledDates: [.now, .now.addingTimeInterval(60 * 60 * 24 * 3)]
    )
    .padding()
}
