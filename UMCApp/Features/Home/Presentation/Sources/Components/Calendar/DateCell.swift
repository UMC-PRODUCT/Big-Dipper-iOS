//
//  DateCell.swift
//  HomePresentation
//
//  Created by euijjang97 on 8/9/26.
//

import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 캘린더 그리드의 개별 날짜 셀.
struct DateCell: View {

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
                        Circle()
                            .strokeBorder(Color.indigo500, lineWidth: Constants.todayBorderWidth)
                    }
                }

            Circle()
                .fill(hasSchedule ? dotColor : .clear)
                .frame(width: Constants.dotSize, height: Constants.dotSize)
        }
    }

    // MARK: - Function

    private var dayText: String {
        "\(Calendar.kstGregorian.component(.day, from: date))"
    }

    private var dotColor: Color {
        isSelected ? .grey000 : .red500
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: DefaultSpacing.spacing8) {
        DateCell(date: .now, isSelected: true, hasSchedule: true, isToday: true)
        DateCell(date: .now, isSelected: false, hasSchedule: true, isToday: true)
        DateCell(date: .now, isSelected: false, hasSchedule: false, isToday: false)
    }
    .padding()
}
