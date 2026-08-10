//
//  DatePill.swift
//  HomePresentation
//
//  Created by euijjang97 on 8/9/26.
//

import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 가로 스크롤 캘린더의 개별 날짜 캡슐.
///
/// 요일·일·일정 유무를 세로로 쌓아 보여주며, 탭하면 해당 날짜를 선택한다.
struct DatePill: View {

    // MARK: - Property

    let date: Date
    let isSelected: Bool
    let hasSchedule: Bool
    let isToday: Bool
    let action: () -> Void

    fileprivate enum Constants {
        static let pillSize = CGSize(width: 80, height: 140)
        static let dotSize: CGFloat = 6
        static let todayBorderWidth: CGFloat = 2
        /// 셀마다 Calendar를 새로 만들지 않도록 요일 심볼을 한 번만 계산해 재사용한다.
        static let weekdaySymbols = Date.weekDaySymbols()
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            VStack(spacing: DefaultSpacing.spacing16) {
                Text(weekdayText)
                    .appFont(.callout, weight: .semibold, color: isSelected ? .grey000 : .grey600)

                VStack(spacing: DefaultSpacing.spacing8) {
                    Text(dayText)
                        .appFont(.body, weight: .medium, color: isSelected ? .grey000 : .grey900)

                    Circle()
                        .fill(hasSchedule ? dotColor : .clear)
                        .frame(width: Constants.dotSize, height: Constants.dotSize)
                }
            }
            .frame(width: Constants.pillSize.width, height: Constants.pillSize.height)
            .background {
                pillBackground
            }
            .clipShape(.capsule)
            .overlay {
                if isToday && !isSelected {
                    Capsule()
                        .strokeBorder(Color.indigo500, lineWidth: Constants.todayBorderWidth)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Component

    private var pillBackground: some View {
        (isSelected ? Color.indigo500 : Color.grey000)
            .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: - Function

    private var weekdayText: String {
        let index = Calendar.kstGregorian.component(.weekday, from: date) - 1
        guard Constants.weekdaySymbols.indices.contains(index) else { return "" }
        return Constants.weekdaySymbols[index]
    }

    private var dayText: String {
        "\(Calendar.kstGregorian.component(.day, from: date))"
    }

    private var dotColor: Color {
        isSelected ? .grey000 : .red500
    }
}

// MARK: - Preview

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: DefaultSpacing.spacing12) {
        DatePill(date: .now, isSelected: true, hasSchedule: true, isToday: true) {}
        DatePill(date: .now, isSelected: false, hasSchedule: true, isToday: true) {}
        DatePill(date: .now, isSelected: false, hasSchedule: false, isToday: false) {}
    }
    .padding()
}
#endif
