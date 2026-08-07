//
//  DateTimeRow.swift
//  CoreUIComponents
//
//  Created by jaewon Lee on 8/3/26.
//

import CoreDesignSystem
import SwiftUI

/// 날짜와 시간을 각각 탭해서 여닫는 폼 행.
///
/// 행 자체는 값을 바꾸지 않고 "무엇이 선택돼 있는지"와 "어느 피커가 열려 있는지"만 그린다.
/// 실제 값 변경은 이 행 아래에 붙는 ``DatePickerRow``/``TimePickerRow`` 가 담당하므로,
/// 열림 상태는 호출부가 소유한다.
///
/// 일정 등록(스터디·홈)에서 시작/종료·출석 정책 시각을 같은 모양으로 입력받기 위해 공유한다.
public struct DateTimeRow: View, Equatable {

    // MARK: - Property

    /// 행의 제목 (예: 시작, 종료)
    private let title: String
    /// 표시할 날짜 및 시간
    private let date: Date
    /// 하루 종일 여부 — `true` 면 시간 버튼을 감춘다
    private let isAllDay: Bool
    /// 날짜 피커가 열려 있는지 여부 (텍스트 강조에 사용)
    private let isDatePickerActive: Bool
    /// 시간 피커가 열려 있는지 여부 (텍스트 강조에 사용)
    private let isTimePickerActive: Bool
    /// 날짜 버튼 탭 액션
    private let dateTap: () -> Void
    /// 시간 버튼 탭 액션
    private let timeTap: () -> Void

    // MARK: - Initializer

    /// - Parameters:
    ///   - title: 행의 제목
    ///   - date: 표시할 날짜 및 시간
    ///   - isAllDay: 하루 종일 여부 (시간 버튼 표시 여부)
    ///   - isDatePickerActive: 날짜 피커 열림 여부
    ///   - isTimePickerActive: 시간 피커 열림 여부
    ///   - dateTap: 날짜 버튼 탭 액션
    ///   - timeTap: 시간 버튼 탭 액션
    public init(
        title: String,
        date: Date,
        isAllDay: Bool,
        isDatePickerActive: Bool,
        isTimePickerActive: Bool,
        dateTap: @escaping () -> Void,
        timeTap: @escaping () -> Void
    ) {
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.isDatePickerActive = isDatePickerActive
        self.isTimePickerActive = isTimePickerActive
        self.dateTap = dateTap
        self.timeTap = timeTap
    }

    // MARK: - Constants

    fileprivate enum Constants {
        /// 날짜/시간 버튼 내부 패딩
        static let buttonPadding = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    }

    // MARK: - Equatable

    /// 탭 클로저는 매 렌더마다 새로 만들어지므로 비교에서 제외한다.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
            && lhs.date == rhs.date
            && lhs.isAllDay == rhs.isAllDay
            && lhs.isDatePickerActive == rhs.isDatePickerActive
            && lhs.isTimePickerActive == rhs.isTimePickerActive
    }

    // MARK: - Body

    public var body: some View {
        HStack {
            Text(title)

            Spacer()

            valueButton(
                text: date.toYearMonthDay(),
                isActive: isDatePickerActive,
                action: dateTap
            )

            if !isAllDay {
                valueButton(
                    text: date.toHourMinutes(),
                    isActive: isTimePickerActive,
                    action: timeTap
                )
            }
        }
    }

    // MARK: - Function

    /// 날짜/시간 값을 보여주는 알약 버튼.
    ///
    /// 열려 있는 피커의 값만 강조색으로 바꿔, 어느 피커를 조작 중인지 한눈에 보이게 한다.
    private func valueButton(
        text: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .appFont(.body, color: isActive ? Color.red500 : Color.grey900)
                .padding(Constants.buttonPadding)
                .background(Color.grey200, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DateTimeRow") {
    Form {
        DateTimeRow(
            title: "시작",
            date: .now,
            isAllDay: false,
            isDatePickerActive: false,
            isTimePickerActive: true,
            dateTap: {},
            timeTap: {}
        )
    }
}
#endif
