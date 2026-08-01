//
//  ScheduleAttendancePolicy.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 일정에 부착된 출석 시각 임계값
///
/// 서버 V2 일정 응답에 임베드되어 내려오는 동적 정책이다.
/// 컨테이너에서 `nil` 은 출석 비필수 일정을 의미한다.
///
/// > Note: 지오펜스 반경 같은 앱 전역 상수(`AttendancePolicy`)와 이름이 겹치지 않도록
///   `Schedule` 접두사를 부여했다.
public struct ScheduleAttendancePolicy: Equatable, Sendable {

    // MARK: - Property

    /// 출석 체크인 시작 시각 (이전엔 출석 불가)
    public let checkInStartAt: Date

    /// 정시 출석 종료 시각 (이후엔 지각)
    public let onTimeEndAt: Date

    /// 지각 종료 시각 (이후엔 결석)
    public let lateEndAt: Date

    // MARK: - Init

    public init(checkInStartAt: Date, onTimeEndAt: Date, lateEndAt: Date) {
        self.checkInStartAt = checkInStartAt
        self.onTimeEndAt = onTimeEndAt
        self.lateEndAt = lateEndAt
    }
}
