//
//  ScheduleCard.swift
//  HomePresentation
//
//  Created by euijjang97 on 7/11/26.
//

import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 홈 화면 일정 캘린더 카드 — 월별 그리드로 일정 유무를 표시한다.
///
/// 슬라이스 2(#914) 범위는 캘린더 그리드 표시만 다룬다. 가로 스크롤(리스트) 모드 전환은
/// 후속 슬라이스에서 추가한다.
struct ScheduleCard: View, Equatable {

    // MARK: - Property

    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let scheduledDates: Set<Date>

    @State private var showDatePicker = false

    // MARK: - Constants

    fileprivate enum Constants {
        static let padding: CGFloat = 24
        static let weekdayCount = 7
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectedDate == rhs.selectedDate &&
        lhs.currentMonth == rhs.currentMonth &&
        lhs.scheduledDates == rhs.scheduledDates
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing24) {
            header
            weekdayHeader
            dateGrid
        }
        .padding(Constants.padding)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
        )
        .sheet(isPresented: $showDatePicker) {
            DateSheetPicker(month: $currentMonth, selectedDate: $selectedDate)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                showDatePicker = true
            } label: {
                Text(monthTitle)
                    .appFont(.body, weight: .semibold, color: .grey900)
            }
            Spacer()
            monthStepper
        }
    }

    private var monthStepper: some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(Color.grey600)
    }

    private var monthTitle: String {
        let calendar = Calendar.kstGregorian
        let year = calendar.component(.year, from: currentMonth)
        let month = calendar.component(.month, from: currentMonth)
        return "\(year)년 \(month)월 일정"
    }

    private func changeMonth(by offset: Int) {
        guard
            let newMonth = Calendar.kstGregorian.date(byAdding: .month, value: offset, to: currentMonth)
        else { return }

        withAnimation(.smooth(duration: DefaultConstant.animationTime)) {
            currentMonth = newMonth
        }
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
        Array(repeating: GridItem(.flexible(), spacing: DefaultSpacing.spacing8), count: Constants.weekdayCount)
    }

    private var dateGrid: some View {
        LazyVGrid(columns: columns, spacing: DefaultSpacing.spacing8) {
            ForEach(adjustedDates, id: \.self) { date in
                if Calendar.kstGregorian.isDate(date, equalTo: currentMonth, toGranularity: .month) {
                    ScheduleDateCell(
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

    /// 표시 월의 날짜 앞/뒤에 인접 월의 날짜를 채워 7일 단위 그리드를 완성한다.
    private var adjustedDates: [Date] {
        let calendar = Calendar.kstGregorian
        let datesInMonth = currentMonth.datesInMonth()
        guard let firstDate = datesInMonth.first, let lastDate = datesInMonth.last else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDate)
        let lastWeekday = calendar.component(.weekday, from: lastDate)

        var dates: [Date] = []
        let emptyDaysBefore = firstWeekday - 1
        for offset in 0..<emptyDaysBefore {
            if let date = calendar.date(byAdding: .day, value: -(emptyDaysBefore - offset), to: firstDate) {
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

// MARK: - ScheduleDateCell

/// 캘린더 그리드의 개별 날짜 셀.
fileprivate struct ScheduleDateCell: View {

    // MARK: - Property

    let date: Date
    let isSelected: Bool
    let hasSchedule: Bool
    let isToday: Bool

    fileprivate enum Constants {
        static let cellSize: CGFloat = 40
        static let dotSize: CGFloat = 6
        static let todayBorderWidth: CGFloat = 2
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing4) {
            Text(dayText)
                .appFont(.callout, color: isSelected ? .grey000 : .grey900)
                .frame(maxWidth: .infinity)
                .frame(height: Constants.cellSize)
                .background {
                    if isSelected {
                        Color.indigo500.glassEffect(.regular.interactive(), in: .circle)
                    }
                }
                .clipShape(.circle)
                .overlay {
                    if isToday && !isSelected {
                        Circle().strokeBorder(Color.indigo500, lineWidth: Constants.todayBorderWidth)
                    }
                }

            Circle()
                .fill(hasSchedule ? dotColor : .clear)
                .frame(width: Constants.dotSize, height: Constants.dotSize)
        }
    }

    private var dayText: String {
        "\(Calendar.kstGregorian.component(.day, from: date))"
    }

    private var dotColor: Color {
        isSelected ? .grey000 : .red500
    }
}

// MARK: - DateSheetPicker

/// 연월 이동을 위한 휠 스타일 날짜 선택 시트.
fileprivate struct DateSheetPicker: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @Binding var month: Date
    @Binding var selectedDate: Date

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            title
            datePicker
        }
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    private var title: some View {
        HStack {
            Spacer()
            Text("날짜 선택")
                .appFont(.body, weight: .semibold, color: .grey900)
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button(role: .confirm) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo500)
        }
    }

    private var datePicker: some View {
        DatePicker("", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .onChange(of: selectedDate) { _, newDate in
                month = newDate
            }
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    ScheduleCard(
        selectedDate: .constant(.now),
        currentMonth: .constant(.now),
        scheduledDates: [.now, .now.addingTimeInterval(60 * 60 * 24 * 3)]
    )
    .padding()
}
