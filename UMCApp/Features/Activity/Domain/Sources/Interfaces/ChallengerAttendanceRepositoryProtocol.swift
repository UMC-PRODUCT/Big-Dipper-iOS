//
//  ChallengerAttendanceRepositoryProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation

/// 챌린저 본인 시점의 출석 액션
///
/// 관리자 권한 작업(일괄 결정, 위치 변경 등)은 ``OperatorAttendanceRepositoryProtocol``.
public protocol ChallengerAttendanceRepositoryProtocol {

    // MARK: - 액션

    /// GPS 출석 요청
    ///
    /// - Parameters:
    ///   - scheduleId: 출석할 일정 식별자
    ///   - latitude: 체크인 위도
    ///   - longitude: 체크인 경도
    ///   - locationVerified: 클라이언트 측 지오펜스 검증 결과
    func requestAttendance(
        scheduleId: Int,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    ) async throws -> AttendanceDecisionResult

    /// 사유 결석/지각 제출
    ///
    /// - Parameters:
    ///   - scheduleId: 사유 제출할 일정 식별자
    ///   - excuseReason: 사유 내용
    ///   - isVerified: 클라이언트 측 위치 인증 여부 (사유와 함께 보고)
    ///   - latitude: 보고 시점 위도
    ///   - longitude: 보고 시점 경도
    func submitExcuse(
        scheduleId: Int,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    ) async throws -> AttendanceDecisionResult

    // MARK: - 외부 도메인 의존 (별도 이슈로 추가 예정)
    //
    // `fetchMySchedulesForAttendance(from:to:) async throws -> [ScheduleDetailData]`
    // 는 `ScheduleDetailData` 가 Schedule Feature 모듈에 정의될 예정이라 본 PR 에서 제외.
    // Schedule 모듈 이식 후속 이슈에서 추가합니다.
}
