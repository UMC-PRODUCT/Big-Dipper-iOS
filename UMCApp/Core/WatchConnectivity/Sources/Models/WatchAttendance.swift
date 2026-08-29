//
//  WatchAttendance.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/29/26.
//

import Foundation

// MARK: - WatchAttendanceRequest

/// 워치가 iPhone 에 위임하는 GPS 출석 요청.
///
/// 워치는 서버를 직접 치지 않는다. 좌표와 **측정 시각**을 iPhone 에 넘기면 iPhone 이
/// `POST /api/v2/schedules/{scheduleId}/attendances/request` 를 대신 호출한다.
public struct WatchAttendanceRequest: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 서버 정수 식별자를 String 으로 보존한다 (절대 규칙 #2 · `ScheduleDetailData.scheduleId` 와 동형).
    public let scheduleId: String
    public let latitude: Double
    public let longitude: Double
    /// 클라이언트 측 지오펜스 검증 결과. 서버 바디의 `locationVerified` 와 같은 값이다.
    public let locationVerified: Bool
    /// **기기에서 위치를 측정한 시각.** 오프라인 큐가 늦게 도착해도 이 시각으로 판정되므로,
    /// 전송 시각이 아니라 측정 시각이라는 점이 이 필드의 존재 이유다.
    public let measuredAt: Date

    // MARK: - Constant

    /// 서버가 `measuredAt` 을 판정에 쓰는 최대 지연(180분). 이 값을 넘긴 큐 항목은 보내 봐야
    /// 수신 시각으로 판정되어 결석이 되므로 워치가 스스로 버린다.
    public static let maxQueueAge: TimeInterval = 180 * 60

    // MARK: - Init

    public init(
        scheduleId: String,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool,
        measuredAt: Date
    ) {
        self.scheduleId = scheduleId
        self.latitude = latitude
        self.longitude = longitude
        self.locationVerified = locationVerified
        self.measuredAt = measuredAt
    }

    // MARK: - Function

    /// 큐에서 버려야 하는 항목인지. 경계값(정확히 180분)은 **아직 유효**로 본다.
    public func isExpired(now: Date = Date()) -> Bool {
        now.timeIntervalSince(measuredAt) > Self.maxQueueAge
    }
}

// MARK: - WatchAttendanceResult

/// 출석 결정 결과. iPhone → 워치 단방향(푸시 반영)과 왕복 응답 양쪽에서 쓴다.
public struct WatchAttendanceResult: Codable, Sendable, Equatable {

    // MARK: - Property

    public let scheduleId: String
    /// **서버 `AttendanceStatus` 원본 문자열** — `PRESENT` / `LATE` / `EXCUSED` / `ABSENT`
    /// / `PENDING` / `PRESENT_PENDING` / `LATE_PENDING` / `EXCUSED_PENDING`.
    ///
    /// 앱의 축약 enum(`AttendanceStatus`·`ScheduleAttendanceStatus`)으로 좁히지 **않는다.**
    /// 두 enum 모두 `EXCUSED` 를 `.present` 로 합치는데, 워치는 공결 전용 결과 화면을 따로
    /// 그려야 하므로 합치는 순간 그 사용자가 볼 화면이 없어진다.
    public let status: String
    /// 운영진이 결정한 시각. 아직 대기 중이면 `nil`.
    public let decidedAt: Date?
    /// 사용자가 적은 사유를 운영진 결정 사유보다 우선한다
    /// (`AttendanceDecisionResult.toAttendance` 의 `excuseReason ?? decisionReason` 규칙과 동일).
    public let reason: String?

    // MARK: - Init

    public init(scheduleId: String, status: String, decidedAt: Date?, reason: String?) {
        self.scheduleId = scheduleId
        self.status = status
        self.decidedAt = decidedAt
        self.reason = reason
    }
}
