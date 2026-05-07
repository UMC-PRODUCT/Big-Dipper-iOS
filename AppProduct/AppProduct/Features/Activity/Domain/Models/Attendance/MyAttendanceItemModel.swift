//
//  MyAttendanceItemModel.swift
//  AppProduct
//
//  Created by 김미주 on 1/9/26.
//

import Foundation

// MARK: - MyAttendanceItemModel

struct MyAttendanceItemModel: Equatable, Identifiable {
    let id: UUID
    let week: Int
    let title: String
    let startTime: Date
    let endTime: Date
    let status: MyAttendanceItemStatus
    let category: ScheduleIconCategory

    // MARK: - Computed Properties

    /// 주차 표시 텍스트 (예: "1주차")
    var weekText: String {
        "\(week)주차"
    }

    /// 시간 범위 텍스트 (예: "14:00 - 18:00")
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

// MARK: - Session Conversion

extension MyAttendanceItemModel {
    /// Session에서 변환
    /// - Parameters:
    ///   - session: 변환할 세션
    ///   - category: ML 분류 결과 (기본값: .general)
    /// - Note: pending 상태는 nil 반환
    init?(from session: Session, category: ScheduleIconCategory = .general) {
        guard let itemStatus = MyAttendanceItemStatus(from: session.attendanceStatus) else {
            return nil
        }

        self.id = session.info.id
        self.week = session.info.week
        self.title = session.info.title
        self.startTime = session.info.startTime
        self.endTime = session.info.endTime
        self.status = itemStatus
        self.category = category
    }
}

// MARK: - ScheduleDetailData Conversion

extension MyAttendanceItemModel {
    /// ScheduleDetailData (V2)에서 변환
    /// - Note: attendanceStatus가 nil(beforeAttendance)인 일정은 nil 반환
    init?(from data: ScheduleDetailData) {
        let status = data.attendanceStatus ?? .beforeAttendance
        guard let itemStatus = MyAttendanceItemStatus(from: status) else {
            return nil
        }

        self.id = data.id
        self.week = 0
        self.title = data.name
        self.startTime = data.startsAt
        self.endTime = data.endsAt
        self.status = itemStatus
        self.category = .general
    }
}

// MARK: - Preview Support

#if DEBUG
extension MyAttendanceItemModel {
    /// Preview용 직접 생성
    init(
        week: Int,
        title: String,
        startTime: Date,
        endTime: Date,
        status: MyAttendanceItemStatus,
        category: ScheduleIconCategory = .general
    ) {
        self.id = UUID()
        self.week = week
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.category = category
    }
}
#endif
