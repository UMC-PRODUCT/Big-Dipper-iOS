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
    /// 출석 정책 (`nil` = 정책 정보 없음)
    let attendancePolicy: AttendancePolicy?
    /// 장소명 (`nil` = 장소 미지정)
    let locationName: String?
    /// 비대면 여부
    let isOnline: Bool

    // MARK: - Computed Properties

    /// 주차 표시 텍스트 (예: "1주차")
    var weekText: String {
        "\(week)주차"
    }

    /// 날짜 표시 텍스트 (예: "6월 11일 (목)")
    var dateText: String {
        Self.kstDateFormatter.string(from: startTime)
    }

    /// 시간 범위 텍스트 (예: "14:00 - 18:00")
    var timeRange: String {
        let start = Self.kstTimeFormatter.string(from: startTime)
        let end = Self.kstTimeFormatter.string(from: endTime)
        return "\(start) - \(end)"
    }

    // MARK: - Formatter

    private static let kstDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .kst
        formatter.dateFormat = "M월 d일 (E)"
        return formatter
    }()

    private static let kstTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .kst
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
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
        self.attendancePolicy = nil
        self.locationName = nil
        self.isOnline = false
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
        self.attendancePolicy = data.attendancePolicy
        self.locationName = data.location?.locationName
        self.isOnline = data.isOnline
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
        category: ScheduleIconCategory = .general,
        attendancePolicy: AttendancePolicy? = nil,
        locationName: String? = nil,
        isOnline: Bool = false
    ) {
        self.id = UUID()
        self.week = week
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.category = category
        self.attendancePolicy = attendancePolicy
        self.locationName = locationName
        self.isOnline = isOnline
    }
}
#endif
