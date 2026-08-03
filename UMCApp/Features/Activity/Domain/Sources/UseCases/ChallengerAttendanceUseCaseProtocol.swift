//
//  ChallengerAttendanceUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/20/26.
//

import Foundation
import HomeDomain

/// 챌린저 시점의 출석 도메인 진입점
///
/// GPS 스마트 출석의 핵심 UseCase. 위치 권한/지오펜스 가드, 사유 제출, 시간 윈도우 판정 등
/// 챌린저가 출석 화면에서 수행하는 모든 액션을 단일 Protocol 로 노출합니다.
///
/// - 관리자 권한 작업(일괄 결정, 위치 변경 등)은 `OperatorAttendanceUseCaseProtocol` 사용.
/// - `LocationProviding` 추상화에 의존하여 `LocationManager` 싱글톤과 분리되어 있습니다.
public protocol ChallengerAttendanceUseCaseProtocol {

    // MARK: - 상태

    /// 추적 중인 지오펜스 중 어느 하나라도 현재 위치가 안에 있는지 (UI 상태 표시용 fallback)
    ///
    /// - Important: 특정 일정 출석 가능 여부는 `requestGPSAttendance` 내부의
    ///   `isInside(geofenceId:)` 식별자 기반 판정을 사용합니다. 본 프로퍼티는 멀티 지오펜스
    ///   시나리오에서 어느 지오펜스인지 구분하지 않습니다.
    var isInsideGeofence: Bool { get }

    /// 시스템 위치 권한이 부여된 상태인지
    var isLocationAuthorized: Bool { get }

    // MARK: - 일정 조회

    /// 출석 가능한 일정 목록 조회
    ///
    /// 출석 정책이 붙어 있고, 본인이 참여자이며, 출석 창이 아직 닫히지 않은 일정만 돌려줍니다.
    /// 출석 창이 아직 열리지 않은 일정도 포함해 View 가 "출석 전" 으로 표시할 수 있게 합니다.
    ///
    /// - Parameter now: 기준 시각. 테스트는 결정론적 epoch 를 주입하고, 프로덕션 호출은
    ///   기본 오버로드(`Date()`) 를 사용합니다 (`isWithinAttendanceTime(info:now:)` 와 동일 패턴).
    /// - Returns: 시작 시각 오름차순 정렬된 일정 목록
    func fetchAvailableSchedules(now: Date) async throws -> [ScheduleDetailData]

    /// 내 출석 이력 조회
    ///
    /// 최근 6개월 구간에서 출석 정책이 붙은 일정을 돌려줍니다.
    ///
    /// - Parameter now: 기준 시각. `fetchAvailableSchedules(now:)` 와 동일 규약.
    /// - Returns: 시작 시각 오름차순 정렬된 일정 목록
    func fetchMyHistory(now: Date) async throws -> [ScheduleDetailData]

    // MARK: - 출석 액션

    /// GPS 기반 출석 요청
    ///
    /// - Parameters:
    ///   - sessionId: 결과 `Attendance` 에 부착할 세션 식별자
    ///   - userId: 결과 `Attendance` 에 부착할 사용자 식별자
    ///   - scheduleId: 일정 식별자 (서버 String ID)
    /// - throws:
    ///   - `LocationError.notAuthorized`: 위치 권한 없음
    ///   - `LocationError.locationFailed`: 현재 좌표 획득 실패
    ///   - `DomainError.attendanceOutOfRange`: 지오펜스 밖
    func requestGPSAttendance(
        sessionId: SessionID,
        userId: UserID,
        scheduleId: String
    ) async throws -> Attendance

    /// 지각 사유 제출
    ///
    /// `submitAbsentReason` 과 의미가 다른 별도 도메인 액션입니다. 현재는 동일 서버 엔드포인트로
    /// 수렴하지만, 호출부가 "지각/불참"을 어휘로 구분하도록 진입점을 분리해 노출합니다.
    ///
    /// - throws:
    ///   - `DomainError.attendanceReasonRequired`: 빈 사유(공백 trim 결과 빈 문자열)
    func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance

    /// 불참 사유 제출
    ///
    /// `submitLateReason` 참고 — 별도 도메인 의미를 갖는 진입점입니다.
    ///
    /// - throws:
    ///   - `DomainError.attendanceReasonRequired`: 빈 사유(공백 trim 결과 빈 문자열)
    func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance

    // MARK: - 시간 윈도우

    /// 기준 시각(`now`)이 어느 출석 시간대에 속하는지 판정 (순수 함수)
    ///
    /// `AttendancePolicy` 의 임계 시간을 기준으로 분기합니다.
    /// 종일 일정(`isAllDay`)은 시작-종료 시각 사이를 단일 `.onTime` 으로 처리합니다.
    ///
    /// - Parameters:
    ///   - info: 판정할 세션 정보 (시작/종료/종일 여부)
    ///   - now: 기준 시각. 테스트는 결정론적 epoch 를 주입하고, 프로덕션 호출은 기본 오버로드(`Date()`) 를 사용합니다.
    func isWithinAttendanceTime(info: SessionInfo, now: Date) -> AttendanceTimeWindow

    // MARK: - 위치/지오펜스

    /// 현재 좌표를 주소(도메인 모델)로 역지오코딩
    /// - throws: `LocationError.locationFailed` (좌표 없음) 등
    func getAddressToCurrentLocation() async throws -> Address

    /// 등록된 모든 지오펜스 모니터링 중지
    func stopGeofenceMonitoring() async
}

// MARK: - Default Implementations

extension ChallengerAttendanceUseCaseProtocol {

    /// 프로덕션 편의 오버로드 — 기준 시각으로 `Date()` 를 사용
    public func isWithinAttendanceTime(info: SessionInfo) -> AttendanceTimeWindow {
        isWithinAttendanceTime(info: info, now: Date())
    }

    /// 프로덕션 편의 오버로드 — 기준 시각으로 `Date()` 를 사용
    public func fetchAvailableSchedules() async throws -> [ScheduleDetailData] {
        try await fetchAvailableSchedules(now: Date())
    }

    /// 프로덕션 편의 오버로드 — 기준 시각으로 `Date()` 를 사용
    public func fetchMyHistory() async throws -> [ScheduleDetailData] {
        try await fetchMyHistory(now: Date())
    }
}
