//
//  OperatorAttendanceUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation

/// 운영진 시점의 출석 관리 도메인 진입점
///
/// Mobile-First Admin 의 핵심 UseCase. 일정 출석 현황 조회 · 일괄 승인/반려 · 위치 변경 등
/// 운영진이 출석 관리 화면에서 수행하는 액션을 단일 Protocol 로 노출합니다.
///
/// - 챌린저 본인의 출석 요청은 `ChallengerAttendanceUseCaseProtocol` 사용.
/// - 모든 서버 식별자는 String 으로 전 레이어 통일됩니다.
public protocol OperatorAttendanceUseCaseProtocol {

    // MARK: - 조회

    /// 운영진용 일정 출석 현황 목록 조회
    ///
    /// 직책별 조회 범위는 서버에서 자동 분기됩니다.
    ///
    /// - Parameters:
    ///   - from: 조회 시작 시각 (`nil` 이면 서버 기본값)
    ///   - to: 조회 종료 시각 (`nil` 이면 서버 기본값)
    ///   - attendanceStatus: 필터링할 출석 상태 (`nil` 이면 모든 상태)
    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> [ScheduleAttendanceInfo]

    /// 단일 일정 출석 현황 조회
    ///
    /// - Parameters:
    ///   - scheduleId: 일정 식별자 (서버 String ID)
    ///   - attendanceStatus: 필터링할 출석 상태 (`nil` 이면 모든 상태)
    func fetchAttendanceDetail(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> ScheduleAttendanceInfo

    // MARK: - 액션

    /// 출석 일괄 승인/반려
    ///
    /// - Parameters:
    ///   - scheduleId: 일정 식별자 (서버 String ID)
    ///   - decisions: 참여자별 승인/반려 결정 목록
    func decideAttendances(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult]

    /// 세션 출석 위치 변경
    ///
    /// - Parameters:
    ///   - scheduleId: 일정 식별자 (서버 String ID)
    ///   - locationName: 변경할 장소 이름
    ///   - latitude: 변경할 위도
    ///   - longitude: 변경할 경도
    func updateScheduleLocation(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws
}
