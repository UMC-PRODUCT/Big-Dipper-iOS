//
//  ScheduleCard.swift
//  HomePresentation
//
//  Created by euijjang97 on 7/11/26.
//

import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 홈 화면 일정 캘린더 카드.
///
/// 헤더의 세그먼트로 월별 그리드(``CalendarGridCard``)와 가로 스크롤(``CalendarHorizonCard``)
/// 모드를 전환한다. 헤더는 두 모드가 공유하므로 유리 카드 바깥에 둔다.
struct ScheduleCard: View, Equatable {

    // MARK: - Property

    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let scheduledDates: Set<Date>

    @State private var scheduleMode: ScheduleMode = .grid

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectedDate == rhs.selectedDate &&
        lhs.currentMonth == rhs.currentMonth &&
        lhs.scheduleMode == rhs.scheduleMode &&
        lhs.scheduledDates == rhs.scheduledDates
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            ScheduleHeader(
                month: $currentMonth,
                selectedDate: $selectedDate,
                scheduleMode: $scheduleMode
            )

            calendar
        }
    }

    // MARK: - Component

    private var calendar: some View {
        ZStack {
            if scheduleMode == .horizon {
                CalendarHorizonCard(
                    selectedDate: $selectedDate,
                    month: $currentMonth,
                    scheduledDates: scheduledDates
                )
                .equatable()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id("horizon")
            } else {
                CalendarGridCard(
                    selectedDate: $selectedDate,
                    month: $currentMonth,
                    scheduledDates: scheduledDates
                )
                .equatable()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .id("grid")
            }
        }
        .animation(.smooth(duration: DefaultConstant.animationTime), value: scheduleMode)
    }
}

// MARK: - Preview

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    ScheduleCard(
        selectedDate: .constant(.now),
        currentMonth: .constant(.now),
        scheduledDates: [.now, .now.addingTimeInterval(60 * 60 * 24 * 3)]
    )
    .padding()
}
#endif
