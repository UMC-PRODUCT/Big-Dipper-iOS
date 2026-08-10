//
//  ScheduleHeader.swift
//  HomePresentation
//
//  Created by euijjang97 on 8/9/26.
//

import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 일정 캘린더 카드의 헤더.
///
/// 표시 중인 연월 타이틀(탭 시 날짜 선택 시트), 표시 모드 전환 세그먼트, 월 이동 스테퍼를 제공한다.
struct ScheduleHeader: View {

    // MARK: - Property

    @Binding var month: Date
    @Binding var selectedDate: Date
    @Binding var scheduleMode: ScheduleMode

    @State private var showDatePicker = false

    fileprivate enum Constants {
        static let segmentWidth: CGFloat = 80
        static let sheetHeight: CGFloat = 300
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            title
            Spacer(minLength: DefaultSpacing.spacing8)
            modePicker
            monthStepper
        }
        .sheet(isPresented: $showDatePicker) {
            DateSheetPicker(month: $month, selectedDate: $selectedDate)
                .presentationDetents([.height(Constants.sheetHeight)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Component

    private var title: some View {
        Button {
            showDatePicker = true
        } label: {
            Text(monthTitle)
                .appFont(.body, weight: .semibold, color: .grey900)
                .fixedSize()
        }
    }

    private var modePicker: some View {
        Picker(selection: $scheduleMode) {
            Image(systemName: "calendar")
                .tag(ScheduleMode.grid)
            Image(systemName: "list.bullet")
                .tag(ScheduleMode.horizon)
        } label: {
            Text("일정 표시 모드")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: Constants.segmentWidth)
    }

    private var monthStepper: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
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

    // MARK: - Function

    private var monthTitle: String {
        let calendar = Calendar.kstGregorian
        let year = calendar.component(.year, from: month)
        let monthNumber = calendar.component(.month, from: month)
        return "\(year)년 \(monthNumber)월 일정"
    }

    private func changeMonth(by offset: Int) {
        guard
            let newMonth = Calendar.kstGregorian.date(byAdding: .month, value: offset, to: month)
        else { return }

        withAnimation(.smooth(duration: DefaultConstant.animationTime)) {
            month = newMonth
        }
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

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var month: Date = .now
    @Previewable @State var selectedDate: Date = .now
    @Previewable @State var scheduleMode: ScheduleMode = .grid

    ScheduleHeader(month: $month, selectedDate: $selectedDate, scheduleMode: $scheduleMode)
        .padding()
}
#endif
