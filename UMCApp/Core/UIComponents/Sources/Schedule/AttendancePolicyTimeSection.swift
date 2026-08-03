//
//  AttendancePolicyTimeSection.swift
//  CoreUIComponents
//
//  Created by jaewon Lee on 8/3/26.
//

import SwiftUI

/// 출석 정책 세 시각(출석 시작 · 출석 인정 마감 · 지각 인정 마감) 입력 섹션.
///
/// 세 행 모두 ``DateTimeRow`` + ``DatePickerRow``/``TimePickerRow`` 조합을 그대로 쓰고,
/// 시각이 바뀌면 ``onTimesChanged`` 로 호출부의 dirty 표시·검증 갱신을 트리거한다.
///
/// - Note: "어느 피커가 열려 있는가" 는 이 섹션 밖에서 의미가 없는 순수 표시 상태라 내부
///   `@State` 로 가진다. 열림 상태를 슬롯 하나(`Optional`)로 들고 있으므로 두 피커가 동시에
///   열리는 상태 자체가 표현 불가능하다. 여러 개의 `Bool` 을 호출부에서 받아 매번 "나머지를
///   닫는" 방식은 그 불변식을 호출부마다 다시 지켜야 해서 깨지기 쉽다.
public struct AttendancePolicyTimeSection: View {

    // MARK: - Property

    /// 체크인 시작 시각
    @Binding private var checkInStartAt: Date
    /// 정시 출석 종료 시각
    @Binding private var onTimeEndAt: Date
    /// 지각 종료 시각
    @Binding private var lateEndAt: Date

    /// 시각 변경 콜백 (dirty 표시 + 검증 갱신)
    private let onTimesChanged: () -> Void

    /// 현재 열려 있는 피커 슬롯. `nil` 이면 모두 접힌 상태다.
    @State private var openSlot: PickerSlot?

    // MARK: - Initializer

    /// - Parameters:
    ///   - checkInStartAt: 체크인 시작 시각 바인딩
    ///   - onTimeEndAt: 정시 출석 종료 시각 바인딩
    ///   - lateEndAt: 지각 종료 시각 바인딩
    ///   - onTimesChanged: 세 시각 중 하나라도 바뀌었을 때 호출되는 콜백
    public init(
        checkInStartAt: Binding<Date>,
        onTimeEndAt: Binding<Date>,
        lateEndAt: Binding<Date>,
        onTimesChanged: @escaping () -> Void
    ) {
        self._checkInStartAt = checkInStartAt
        self._onTimeEndAt = onTimeEndAt
        self._lateEndAt = lateEndAt
        self.onTimesChanged = onTimesChanged
    }

    // MARK: - Body

    public var body: some View {
        Group {
            timeRow(title: "출석 시작", date: $checkInStartAt, field: .checkIn)
            timeRow(title: "출석 인정 마감", date: $onTimeEndAt, field: .onTime)
            timeRow(title: "지각 인정 마감", date: $lateEndAt, field: .late)
        }
        .onChange(of: checkInStartAt) { onTimesChanged() }
        .onChange(of: onTimeEndAt) { onTimesChanged() }
        .onChange(of: lateEndAt) { onTimesChanged() }
    }

    // MARK: - Function

    /// 한 시각의 입력 행 + 펼쳐진 피커를 함께 그린다.
    @ViewBuilder
    private func timeRow(
        title: String,
        date: Binding<Date>,
        field: PickerSlot.Field
    ) -> some View {
        let dateSlot = PickerSlot(field: field, component: .date)
        let timeSlot = PickerSlot(field: field, component: .time)

        DateTimeRow(
            title: title,
            date: date.wrappedValue,
            isAllDay: false,
            isDatePickerActive: openSlot == dateSlot,
            isTimePickerActive: openSlot == timeSlot,
            dateTap: { toggle(dateSlot) },
            timeTap: { toggle(timeSlot) }
        )
        .equatable()

        if openSlot == dateSlot {
            DatePickerRow(date: date)
        }

        if openSlot == timeSlot {
            TimePickerRow(date: date)
        }
    }

    /// 같은 슬롯을 다시 누르면 접고, 다른 슬롯을 누르면 그쪽으로 옮긴다.
    private func toggle(_ slot: PickerSlot) {
        withAnimation {
            openSlot = (openSlot == slot) ? nil : slot
        }
    }

    // MARK: - PickerSlot

    /// 열려 있을 수 있는 피커 하나를 가리키는 식별자.
    ///
    /// "어느 시각(`field`)의 어느 피커(`component`)" 를 한 값으로 묶어, 열림 상태를
    /// `PickerSlot?` 하나로 표현할 수 있게 한다.
    private struct PickerSlot: Hashable {

        /// 세 출석 정책 시각 중 하나
        enum Field: Hashable {
            case checkIn
            case onTime
            case late
        }

        /// 같은 시각을 편집하는 두 피커 중 하나
        enum Component: Hashable {
            case date
            case time
        }

        let field: Field
        let component: Component
    }
}

// MARK: - Preview

#if DEBUG
#Preview("AttendancePolicyTimeSection") {
    @Previewable @State var checkIn: Date = .now
    @Previewable @State var onTime: Date = .now.addingTimeInterval(600)
    @Previewable @State var late: Date = .now.addingTimeInterval(1_200)

    return Form {
        Section("출석 정책") {
            AttendancePolicyTimeSection(
                checkInStartAt: $checkIn,
                onTimeEndAt: $onTime,
                lateEndAt: $late,
                onTimesChanged: {}
            )
        }
    }
}
#endif
