//
//  CalendarHorizonCard.swift
//  HomePresentation
//
//  Created by euijjang97 on 8/9/26.
//

import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 표시 월의 날짜를 가로로 나열해 보여주는 캘린더 카드.
///
/// 각 날짜 캡슐이 개별 유리 배경을 가지므로 그리드 모드와 달리 바깥 유리 컨테이너를 두지 않는다.
struct CalendarHorizonCard: View, Equatable {

    // MARK: - Property

    @Binding var selectedDate: Date
    @Binding var month: Date
    let scheduledDates: Set<Date>

    @State private var scrolledDate: Date?

    fileprivate enum Constants {
        static let contentHeight: CGFloat = 200
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectedDate == rhs.selectedDate &&
        lhs.month == rhs.month &&
        lhs.scheduledDates == rhs.scheduledDates
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: DefaultSpacing.spacing12) {
                ForEach(dates, id: \.self) { date in
                    datePill(date)
                }
            }
            .scrollTargetLayout()
            .frame(height: Constants.contentHeight)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolledDate, anchor: .center)
        .task {
            scrollToFocusedDate()
        }
        .onChange(of: month) { _, _ in
            scrollToFocusedDate()
        }
    }

    // MARK: - Component

    private func datePill(_ date: Date) -> some View {
        DatePill(
            date: date,
            isSelected: date.isSameDay(selectedDate),
            hasSchedule: hasSchedule(date),
            isToday: date.isSameDay(.now)
        ) {
            withAnimation(.easeInOut(duration: DefaultConstant.animationTime)) {
                selectedDate = date
                if !Calendar.kstGregorian.isDate(date, equalTo: month, toGranularity: .month) {
                    month = date
                }
            }
        }
        .id(date)
    }

    // MARK: - Function

    private var dates: [Date] {
        month.datesInMonth()
    }

    private func hasSchedule(_ date: Date) -> Bool {
        scheduledDates.contains { $0.isSameDay(date) }
    }

    /// 표시할 날짜 중 오늘 → 선택 날짜 → 첫 날짜 순으로 스크롤 위치를 맞춘다.
    private func scrollToFocusedDate() {
        if let today = dates.first(where: { $0.isSameDay(.now) }) {
            scrolledDate = today
        } else if let selected = dates.first(where: { $0.isSameDay(selectedDate) }) {
            scrolledDate = selected
        } else {
            scrolledDate = dates.first
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var selectedDate: Date = .now
    @Previewable @State var month: Date = .now

    CalendarHorizonCard(
        selectedDate: $selectedDate,
        month: $month,
        scheduledDates: [.now, .now.addingTimeInterval(60 * 60 * 24 * 3)]
    )
}
#endif
