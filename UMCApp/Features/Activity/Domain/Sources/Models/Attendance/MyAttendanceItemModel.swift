//
//  MyAttendanceItemModel.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation
import HomeDomain
import UMCFoundation

// MARK: - MyAttendanceItemModel

/// 내 출석 이력 화면에서 사용하는 표시용 모델
///
/// `Session` 또는 `AttendanceHistoryItem` 으로부터 변환되며,
/// 화면에 노출할 주차/시간/카테고리/상태 정보를 정규화합니다.
public struct MyAttendanceItemModel: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let week: Int
    public let title: String
    public let startTime: Date
    public let endTime: Date
    public let status: MyAttendanceItemStatus
    public let category: ScheduleIconCategory

    /// 일정에 설정된 출석 정책 (`nil` = 아직 조회되지 않음)
    ///
    /// 출석 이력 카드를 펼쳤을 때 보여줄 정책 3개 시각의 원본입니다.
    public let attendancePolicy: ScheduleAttendancePolicy?

    /// 장소명 (`nil` = 장소 미지정)
    ///
    /// - Note: 현재 두 변환 경로(`Session` / `AttendanceHistoryItem`) 모두 장소명을
    ///   싣지 않아 항상 `nil` 입니다. 장소를 담은 일정 상세(`ScheduleDetailData`)는
    ///   Home 도메인 소유이고 Activity 는 Home 에 의존하지 않으므로, 값을 채우려면
    ///   해당 페이로드를 Activity 가 읽을 수 있는 경로가 먼저 생겨야 합니다.
    ///   그때 변환 경로만 값을 채우면 카드는 그대로 동작합니다.
    public let locationName: String?

    /// 비대면 진행 여부
    ///
    /// - Note: `locationName` 과 같은 사유로 현재는 항상 `false` 입니다.
    public let isOnline: Bool

    public init(
        id: UUID = .init(),
        week: Int,
        title: String,
        startTime: Date,
        endTime: Date,
        status: MyAttendanceItemStatus,
        category: ScheduleIconCategory = .general,
        attendancePolicy: ScheduleAttendancePolicy? = nil,
        locationName: String? = nil,
        isOnline: Bool = false
    ) {
        self.id = id
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

    // MARK: - Computed

    /// 주차 표시 텍스트 (예: "1주차")
    public var weekText: String {
        "\(week)주차"
    }

    /// 날짜 표시 텍스트 (예: "6월 11일 (목)")
    public var dateText: String {
        Self.kstDateFormatter.string(from: startTime)
    }

    /// 시간 범위 텍스트 (예: "14:00 - 18:00")
    ///
    /// 서버 시각은 KST 기준이므로 기기 타임존과 무관하게 같은 문자열이 나오도록
    /// KST 고정 포맷터(`Date.timeRange(to:)`)를 사용합니다.
    public var timeRange: String {
        startTime.timeRange(to: endTime)
    }

    // MARK: - Formatter

    private static let kstDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .kst
        formatter.dateFormat = "M월 d일 (E)"
        return formatter
    }()
}

// MARK: - Session Conversion

public extension MyAttendanceItemModel {
    /// Session에서 변환
    /// - Parameters:
    ///   - session: 변환할 세션
    ///   - category: ML 분류 결과 (기본값: .general)
    ///   - attendancePolicy: 해당 세션의 출석 정책 (기본값: nil — 아직 조회 전)
    /// - Note: pending 상태는 nil 반환
    @MainActor
    init?(
        from session: Session,
        category: ScheduleIconCategory = .general,
        attendancePolicy: ScheduleAttendancePolicy? = nil
    ) {
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
        self.attendancePolicy = attendancePolicy
        self.locationName = nil
        self.isOnline = false
    }
}

// MARK: - AttendanceHistoryItem Conversion

public extension MyAttendanceItemModel {
    /// AttendanceHistoryItem에서 변환
    /// - Note: beforeAttendance 상태는 nil 반환
    init?(from item: AttendanceHistoryItem) {
        guard let itemStatus = MyAttendanceItemStatus(from: item.status) else {
            return nil
        }

        self.id = item.id
        self.week = 0
        self.title = item.scheduleName
        self.startTime = Self.parseTimeString(item.startTime)
        var parsedEnd = Self.parseTimeString(item.endTime)
        // FIXME: 자정 넘김 휴리스틱 — 서버가 ISO 8601 datetime 반환 시 제거 (#304)
        if parsedEnd < self.startTime {
            parsedEnd = Calendar.current.date(
                byAdding: .day, value: 1, to: parsedEnd
            ) ?? parsedEnd
        }
        self.endTime = parsedEnd
        self.status = itemStatus
        self.category = .general
        self.attendancePolicy = nil
        self.locationName = nil
        self.isOnline = false
    }
}

// MARK: - Internal Helper

extension MyAttendanceItemModel {
    /// "HH:mm:ss" 또는 "HH:mm" → 오늘 Date 변환
    ///
    /// - Note: 외부 모듈 노출이 불필요한 헬퍼이므로 별도 extension 으로 분리해
    ///   default `internal` 접근으로 둡니다. 테스트는 `@testable import` 로 접근.
    static func parseTimeString(_ timeString: String) -> Date {
        if let isoDate = ServerDateTimeConverter.parseUTCDateTime(timeString) {
            return isoDate
        }

        let calendar = Calendar.current
        let now = Date()
        for format in ["HH:mm:ss", "HH:mm"] {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "ko_KR")
            if let time = formatter.date(from: timeString) {
                var components = calendar.dateComponents(
                    [.year, .month, .day], from: now
                )
                let timeComponents = calendar.dateComponents(
                    [.hour, .minute, .second], from: time
                )
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                components.second = timeComponents.second
                if let date = calendar.date(from: components) {
                    return date
                }
            }
        }
        return now
    }
}
