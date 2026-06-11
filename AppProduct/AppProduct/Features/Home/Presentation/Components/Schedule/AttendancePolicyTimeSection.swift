//
//  AttendancePolicyTimeSection.swift
//  AppProduct
//
//  Created by jaewon Lee on 5/7/26.
//

import SwiftUI

/// 출석 정책 3개 시각(출석 시작 / 출석 인정 마감 / 지각 인정 마감) 입력 섹션입니다.
///
/// `DateTimeRow` 패턴을 그대로 재사용하며, 시각 변경 시 `onTimesChanged` 콜백으로
/// ViewModel 의 dirty flag 토글과 검증 갱신을 트리거합니다.
struct AttendancePolicyTimeSection: View {

    @Binding var checkInStartAt: Date
    @Binding var onTimeEndAt: Date
    @Binding var lateEndAt: Date

    @Binding var showCheckInDatePicker: Bool
    @Binding var showCheckInTimePicker: Bool
    @Binding var showOnTimeDatePicker: Bool
    @Binding var showOnTimeTimePicker: Bool
    @Binding var showLateDatePicker: Bool
    @Binding var showLateTimePicker: Bool

    let onTimesChanged: () -> Void

    var body: some View {
        Group {
            row(
                title: "출석 시작",
                date: $checkInStartAt,
                isDateActive: showCheckInDatePicker,
                isTimeActive: showCheckInTimePicker,
                dateTap: {
                    withAnimation {
                        showCheckInDatePicker.toggle()
                        closeOthers(except: .checkInDate)
                    }
                },
                timeTap: {
                    withAnimation {
                        showCheckInTimePicker.toggle()
                        closeOthers(except: .checkInTime)
                    }
                }
            )
            picker(condition: showCheckInDatePicker, date: $checkInStartAt, isTime: false)
            picker(condition: showCheckInTimePicker, date: $checkInStartAt, isTime: true)

            row(
                title: "출석 인정 마감",
                date: $onTimeEndAt,
                isDateActive: showOnTimeDatePicker,
                isTimeActive: showOnTimeTimePicker,
                dateTap: {
                    withAnimation {
                        showOnTimeDatePicker.toggle()
                        closeOthers(except: .onTimeDate)
                    }
                },
                timeTap: {
                    withAnimation {
                        showOnTimeTimePicker.toggle()
                        closeOthers(except: .onTimeTime)
                    }
                }
            )
            picker(condition: showOnTimeDatePicker, date: $onTimeEndAt, isTime: false)
            picker(condition: showOnTimeTimePicker, date: $onTimeEndAt, isTime: true)

            row(
                title: "지각 인정 마감",
                date: $lateEndAt,
                isDateActive: showLateDatePicker,
                isTimeActive: showLateTimePicker,
                dateTap: {
                    withAnimation {
                        showLateDatePicker.toggle()
                        closeOthers(except: .lateDate)
                    }
                },
                timeTap: {
                    withAnimation {
                        showLateTimePicker.toggle()
                        closeOthers(except: .lateTime)
                    }
                }
            )
            picker(condition: showLateDatePicker, date: $lateEndAt, isTime: false)
            picker(condition: showLateTimePicker, date: $lateEndAt, isTime: true)
        }
        .onChange(of: checkInStartAt) { onTimesChanged() }
        .onChange(of: onTimeEndAt) { onTimesChanged() }
        .onChange(of: lateEndAt) { onTimesChanged() }
    }

    private func row(
        title: String,
        date: Binding<Date>,
        isDateActive: Bool,
        isTimeActive: Bool,
        dateTap: @escaping () -> Void,
        timeTap: @escaping () -> Void
    ) -> some View {
        DateTimeRow(
            title: title,
            date: date.wrappedValue,
            isAllDay: false,
            isDatePickerActive: isDateActive,
            isTimePickerActive: isTimeActive,
            dateTap: dateTap,
            timeTap: timeTap
        )
        .equatable()
    }

    @ViewBuilder
    private func picker(condition: Bool, date: Binding<Date>, isTime: Bool) -> some View {
        if condition {
            if isTime {
                TimePickerRow(date: date, range: nil)
            } else {
                DatePickerRow(date: date, range: nil)
            }
        }
    }

    private func closeOthers(except keep: PickerSlot) {
        if keep != .checkInDate { showCheckInDatePicker = false }
        if keep != .checkInTime { showCheckInTimePicker = false }
        if keep != .onTimeDate { showOnTimeDatePicker = false }
        if keep != .onTimeTime { showOnTimeTimePicker = false }
        if keep != .lateDate { showLateDatePicker = false }
        if keep != .lateTime { showLateTimePicker = false }
    }

    private enum PickerSlot {
        case checkInDate, checkInTime, onTimeDate, onTimeTime, lateDate, lateTime
    }
}
