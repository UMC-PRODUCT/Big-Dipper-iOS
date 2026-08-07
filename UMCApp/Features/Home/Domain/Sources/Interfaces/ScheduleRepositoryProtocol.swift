//
//  ScheduleRepositoryProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 7/11/26.
//

import Foundation

/// 일정 데이터 접근 계층 인터페이스.
///
/// 일정 도메인(`/api/v2/schedules`)의 단일 진입점이다. 홈 캘린더 조회뿐 아니라 출석 화면의
/// 일정 목록 조회와 스터디 일정 등록도 이 프로토콜을 통해 이뤄지므로, 같은 엔드포인트를
/// feature 별로 다시 정의하지 않는다.
///
/// 출석 액션(요청·사유 제출·승인)은 `ActivityDomain` 의
/// `ChallengerAttendanceRepositoryProtocol` / `OperatorAttendanceRepositoryProtocol` 담당이다.
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

    /// 단일 일정 상세 조회. 목록과 동일 스키마이므로 같은 도메인 모델을 돌려준다.
    func fetchScheduleDetail(scheduleId: String) async throws -> ScheduleDetailData

    /// 일정을 생성하고 생성된 일정 식별자를 돌려준다.
    ///
    /// - Returns: 생성된 일정 식별자 (서버 정수를 절대 규칙 #2 에 따라 `String` 으로 보존)
    func createSchedule(_ request: ScheduleCreationRequest) async throws -> String

    /// 일정을 삭제한다.
    ///
    /// 스터디 일정 등록 2단계(그룹 연결)가 실패했을 때 1단계 일정을 되돌리는 용도로 쓴다.
    ///
    /// - Note: 서버는 출석 기록이 있는 일정의 일반 삭제를 거부한다.
    func deleteSchedule(scheduleId: String) async throws
}
