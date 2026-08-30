//
//  WatchSessionState.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/29/26.
//

import Foundation

// MARK: - WatchSessionState

/// iPhone 이 워치에 밀어 넣는 **화면 한 장을 그리는 데 필요한 전부**.
///
/// 워치는 서버를 직접 폴링하지 않는다. 이 스냅샷 하나가 `updateApplicationContext` 로 건너가며,
/// 시스템이 마지막 값을 보존하므로 워치가 콜드런치해도 즉시 그릴 수 있다
/// (「iPhone 과 연결이 끊겼습니다 · 캐시 데이터만 표시」의 그 캐시가 이것이다).
///
/// - Important: 페이로드가 크면 `updateApplicationContext` 가 `payloadTooLarge`(7009)로 던진다.
///   목록 건수를 제한할 책임은 생산자(iPhone)에 있다 — 화면이 무엇을 필요로 하는지 아는 쪽이
///   iPhone 이라 상한을 계약에 상수로 박지 않는다.
public struct WatchSessionState: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 로그인 여부. `false` 면 워치는 목록 대신 「iPhone 에서 로그인해 주세요」를 그린다.
    public let isSignedIn: Bool
    public let schedules: [WatchSchedule]
    public let notices: [WatchNotice]
    /// 스냅샷 생성 시각. 워치가 「N분 전 정보」를 표시하고 신선도를 판단한다.
    public let generatedAt: Date

    // MARK: - Init

    public init(
        isSignedIn: Bool,
        schedules: [WatchSchedule],
        notices: [WatchNotice],
        generatedAt: Date
    ) {
        self.isSignedIn = isSignedIn
        self.schedules = schedules
        self.notices = notices
        self.generatedAt = generatedAt
    }
}

// MARK: - WatchSchedule

/// 원본은 `ScheduleDetailData`. 워치 출석 화면이 쓰는 필드만 옮긴다.
public struct WatchSchedule: Codable, Sendable, Equatable, Identifiable {

    // MARK: - Property

    public var id: String { scheduleId }
    public let scheduleId: String
    /// `ScheduleDetailData.name`.
    public let name: String
    public let startsAt: Date
    public let endsAt: Date
    /// `nil` = 비대면 (`ScheduleDetailData.location` 이 `nil` 인 경우와 같은 의미).
    public let location: WatchScheduleLocation?
    /// `nil` = 출석 비필수 (`ScheduleDetailData.attendancePolicy` 와 같은 의미).
    public let attendanceWindow: WatchAttendanceWindow?
    /// 현재 사용자의 출석 상태. **서버 원본 문자열** (`WatchAttendanceResult.status` 와 동일 규약).
    /// 서버가 내려주지 않았으면 `nil`.
    public let attendanceStatus: String?

    // MARK: - Init

    public init(
        scheduleId: String,
        name: String,
        startsAt: Date,
        endsAt: Date,
        location: WatchScheduleLocation?,
        attendanceWindow: WatchAttendanceWindow?,
        attendanceStatus: String?
    ) {
        self.scheduleId = scheduleId
        self.name = name
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.location = location
        self.attendanceWindow = attendanceWindow
        self.attendanceStatus = attendanceStatus
    }
}

// MARK: - WatchScheduleLocation

/// `ScheduleLocation` 과 1:1.
public struct WatchScheduleLocation: Codable, Sendable, Equatable {

    // MARK: - Property

    public let name: String
    public let latitude: Double
    public let longitude: Double

    // MARK: - Init

    public init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - WatchAttendanceWindow

/// `ScheduleAttendancePolicy` 와 1:1.
///
/// 세 시각을 낱개 옵셔널로 펼치지 않는 이유: 정책은 있거나 없거나지 반쪽일 수 없다.
/// 중첩 옵셔널 하나로 두면 `checkInStartAt` 만 있고 `lateEndAt` 은 없는 상태가 표현 불가능해진다.
///
/// 지오펜스 반경은 싣지 않는다 — `AttendancePolicy.geofenceRadius`(50m)는 일정별 값이 아니라
/// 앱 전역 상수라 워치가 자기 쪽에서 안다.
public struct WatchAttendanceWindow: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 이전엔 출석 불가.
    public let checkInStartAt: Date
    /// 이후엔 지각.
    public let onTimeEndAt: Date
    /// 이후엔 결석.
    public let lateEndAt: Date

    // MARK: - Init

    public init(checkInStartAt: Date, onTimeEndAt: Date, lateEndAt: Date) {
        self.checkInStartAt = checkInStartAt
        self.onTimeEndAt = onTimeEndAt
        self.lateEndAt = lateEndAt
    }
}
