//
//  ScheduleRepositoryProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 7/11/26.
//

import Foundation

/// 홈 일정 캘린더 데이터 접근 계층 인터페이스.
///
/// 조회 전용이다. 출석 관련 액션은 `ActivityDomain`의 `ChallengerAttendanceRepositoryProtocol`
/// 이 담당하고, 일정 생성/수정/삭제는 Schedule 모듈 분리 이슈(#981)에서 다룬다.
public protocol ScheduleRepositoryProtocol {

    /// 기간 내 내 일정을 조회해 KST 자정 기준 날짜별로 그룹핑한다.
    ///
    /// - Parameters:
    ///   - from: 조회 시작 시각 (UTC ISO8601 송신, 통상 KST 월초 자정)
    ///   - to: 조회 종료 시각 (UTC ISO8601 송신, 통상 KST 월말 23:59:59.999)
    ///   - isAttendanceRequired: 출석 필수 일정만 조회할지 여부
    func fetchMySchedules(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]]
}
