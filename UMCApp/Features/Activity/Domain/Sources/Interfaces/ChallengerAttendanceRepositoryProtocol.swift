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
        scheduleId: String,
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
        scheduleId: String,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    ) async throws -> AttendanceDecisionResult

    // MARK: - 일정 조회는 여기 두지 않는다
    //
    // 출석 화면이 쓰는 일정 목록 조회는 `HomeDomain` 의 `ScheduleRepositoryProtocol`
    // (`GET /api/v2/schedules/me`) 이 canonical 이다. 같은 엔드포인트를 Activity 에 다시
    // 정의하지 않고 ``ChallengerAttendanceUseCase`` 가 그 Repository 를 주입받아 사용한다.
}
