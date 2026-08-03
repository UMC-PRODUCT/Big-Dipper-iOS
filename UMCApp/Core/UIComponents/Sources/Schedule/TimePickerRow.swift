//
//  TimePickerRow.swift
//  CoreUIComponents
//
//  Created by jaewon Lee on 8/3/26.
//

import CoreDesignSystem
import SwiftUI

/// 휠(Wheel) 스타일 시각 선택 행.
///
/// ``DateTimeRow`` 의 시간 버튼을 탭했을 때 그 아래에 펼쳐지는 피커다.
public struct TimePickerRow: View, Equatable {

    // MARK: - Property

    /// 선택된 시각
    @Binding private var date: Date
    /// 선택 가능한 시각 범위 (`nil` 이면 제한 없음)
    private let range: ClosedRange<Date>?

    // MARK: - Initializer

    /// - Parameters:
    ///   - date: 선택된 시각 바인딩
    ///   - range: 선택 가능한 시각 범위. 제한이 없으면 `nil`
    public init(date: Binding<Date>, range: ClosedRange<Date>? = nil) {
        self._date = date
        self.range = range
    }

    // MARK: - Equatable

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date
            && lhs.range?.lowerBound == rhs.range?.lowerBound
            && lhs.range?.upperBound == rhs.range?.upperBound
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if let range {
                DatePicker("", selection: $date, in: range, displayedComponents: .hourAndMinute)
            } else {
                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
            }
        }
        .datePickerStyle(.wheel)
        .labelsHidden()
        .tint(.indigo500)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("TimePickerRow") {
    Form {
        TimePickerRow(date: .constant(.now))
    }
}
#endif
