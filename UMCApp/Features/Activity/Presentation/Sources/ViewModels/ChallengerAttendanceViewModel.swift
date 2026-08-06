//
//  ChallengerAttendanceViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 6/12/26.
//

import ActivityDomain
import Foundation
import HomeDomain
import UMCFoundation

/// 챌린저(일반 참여자)의 출석 관련 상태 및 액션을 관리하는 ViewModel
///
/// 출석 요청(GPS)·사유 제출·시간대 판정·지오펜스/권한 상태를 담당합니다.
///
/// 판정 근거가 되는 일정 페이로드는 직접 조회하지 않고, 상위(`ActivityViewModel`)가 소유한
/// 것을 `apply(schedules:)` 로 전달받습니다 — 세션 목록과 같은 엔드포인트라 여기서 또 조회하면
/// 화면 진입 1회에 같은 요청이 두 번 나갑니다.
@MainActor
@Observable
final class ChallengerAttendanceViewModel {

    // MARK: - Property

    private let errorHandler: ErrorHandler
    private let challengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol

    /// 상위가 소유한 출석 가능 일정 페이로드
    ///
    /// 출석 버튼의 `scheduleId` 조회와 서버 정책 기반 시간대 판정에 씁니다.
    private(set) var schedules: [ScheduleDetailData] = []

    // MARK: - Init

    init(
        errorHandler: ErrorHandler,
        challengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol
    ) {
        self.errorHandler = errorHandler
        self.challengerAttendanceUseCase = challengerAttendanceUseCase
    }

    // MARK: - 일정 페이로드

    /// 상위가 조회한 일정 페이로드를 반영합니다.
    func apply(schedules: [ScheduleDetailData]) {
        self.schedules = schedules
    }

    /// SessionID → 일정 매핑
    ///
    /// 상위가 페이로드를 넘기기 전(첫 렌더 프레임)에는 `nil` 입니다.
    func schedule(for sessionId: SessionID) -> ScheduleDetailData? {
        schedules.first { $0.scheduleId == sessionId.value }
    }

    /// SessionID → scheduleId 매핑
    func scheduleId(for sessionId: SessionID) -> String? {
        schedule(for: sessionId)?.scheduleId
    }

    // MARK: - Action

    /// GPS 기반 출석 버튼 탭 처리
    func attendanceButtonTapped(
        userId: UserID,
        session: Session,
        scheduleId: String
    ) async {
        let info = session.info

        // .onTime = 정시 출석 가능 시간대
        guard currentTimeWindow(for: session) == .onTime else { return }

        // 복구용 이전 출석 — .loading 으로 덮어쓰기 전에 캡처해야 함
        let previousAttendance = session.attendance
        session.updateState(.loading)

        do {
            let result = try await challengerAttendanceUseCase.requestGPSAttendance(
                sessionId: info.sessionId,
                userId: userId,
                scheduleId: scheduleId
            )
            session.updateState(.loaded(result))
            session.markSubmitted()

        } catch let error as DomainError {
            session.updateState(.failed(.domain(error)))
        } catch {
            // 기타 에러 (네트워크 등) — 상태 복구 후 Alert
            if let prev = previousAttendance {
                session.updateState(.loaded(prev))
            } else {
                session.updateState(.idle)
            }
            errorHandler.handle(error, context: .init(
                feature: "Activity",
                action: "attendanceButtonTapped",
                retryAction: { [weak self] in
                    await self?.attendanceButtonTapped(
                        userId: userId,
                        session: session,
                        scheduleId: scheduleId
                    )
                }
            ))
        }
    }

    /// 출석 사유 제출
    ///
    /// GPS 출석이 어려운 경우 사유를 제출합니다.
    /// 시간대에 따라 지각/결석 사유 제출로 라우팅됩니다.
    /// - Parameters:
    ///   - userId: 사용자 ID
    ///   - session: 출석 대상 세션
    ///   - reason: 출석 사유
    ///   - scheduleId: 일정 ID (서버 String ID)
    func submitAttendanceReason(
        userId: UserID,
        session: Session,
        reason: String,
        scheduleId: String
    ) async {
        let info = session.info
        let timeWindow = currentTimeWindow(for: session)

        // 복구용 이전 출석 — .loading 으로 덮어쓰기 전에 캡처해야 함
        let previousAttendance = session.attendance
        session.updateState(.loading)

        do {
            let result = try await submitExcuse(
                timeWindow: timeWindow,
                sessionId: info.sessionId,
                userId: userId,
                reason: reason,
                scheduleId: scheduleId
            )
            session.updateState(.loaded(result))
            session.markSubmitted()

        } catch let error as DomainError {
            session.updateState(.failed(.domain(error)))
        } catch {
            // 기타 에러 (네트워크 등) — 상태 복구 후 Alert
            if let prev = previousAttendance {
                session.updateState(.loaded(prev))
            } else {
                session.updateState(.idle)
            }
            errorHandler.handle(error, context: .init(
                feature: "Activity",
                action: "submitAttendanceReason",
                retryAction: { [weak self] in
                    await self?.submitAttendanceReason(
                        userId: userId,
                        session: session,
                        reason: reason,
                        scheduleId: scheduleId
                    )
                }
            ))
        }
    }

    // MARK: - 상태 조회 (View 분기용)

    /// 출석 버튼 위에 표시할 시간대별 안내 문구
    ///
    /// 출석 전(`beforeAttendance`) 상태에서만 문구를 반환합니다.
    /// 정책 시각이 전달된 경우 마감 시각과 남은 시간을 함께 표시하고, 아직 전달 전이면
    /// 시간대 설명만 표시합니다. 만료 시간대는 버튼 문구가 대신하므로 nil.
    func attendanceGuidanceText(for session: Session, at now: Date) -> String? {
        guard session.attendanceStatus == .beforeAttendance else { return nil }

        let timeWindow = currentTimeWindow(for: session, now: now)
        let policy = schedule(for: session.info.sessionId)?.attendancePolicy

        switch timeWindow {
        case .tooEarly:
            guard let start = policy?.checkInStartAt else {
                return "아직 출석 시간 전이에요"
            }
            return "\(start.toHourMinutes())부터 출석할 수 있어요"
        case .onTime:
            guard let end = policy?.onTimeEndAt else {
                return "지금 출석하면 정시로 인정돼요"
            }
            return "출석 인정 마감 \(end.toHourMinutes()) · \(remainingText(until: end, from: now))"
        case .lateWindow:
            guard let end = policy?.lateEndAt else {
                return "지각 시간대예요 — 사유를 제출해 주세요"
            }
            return "지각 인정 마감 \(end.toHourMinutes()) · \(remainingText(until: end, from: now))"
        case .expired:
            return nil
        }
    }

    /// 출석 요청 가능 여부 (시간대 + 지오펜스 + 위치 권한)
    func isAttendanceAvailable(for session: Session) -> Bool {
        session.canRequestAttendance(
            timeWindow: currentTimeWindow(for: session),
            isInsideGeofence: challengerAttendanceUseCase.isInsideGeofence,
            isLocationAuthorized: challengerAttendanceUseCase.isLocationAuthorized
        )
    }

    /// 사유 제출 가능 여부
    func isReasonSubmittable(for session: Session) -> Bool {
        session.canSubmitReason()
    }

    /// 세션의 현재 출석 시간대 (View 분기용)
    func timeWindow(for session: Session, now: Date = Date()) -> AttendanceTimeWindow {
        currentTimeWindow(for: session, now: now)
    }

    /// 사유 제출 보조 링크 노출 여부
    ///
    /// 정시/시작 전에는 GPS 출석이 기본 동작이므로 사유 제출을 보조 링크로 노출합니다.
    /// 지각 시간대에는 사유 제출이 기본 버튼으로 승격되므로 링크를 숨기고,
    /// 마감 후나 이미 제출한 세션에서도 숨깁니다.
    func shouldShowReasonButton(for session: Session) -> Bool {
        let window = currentTimeWindow(for: session)
        return (window == .tooEarly || window == .onTime) && session.canSubmitReason()
    }

    /// 출석 버튼에 표시할 텍스트
    func buttonTitle(for session: Session) -> String {
        session.buttonTitle(
            isLocationAuthorized: challengerAttendanceUseCase.isLocationAuthorized,
            isInsideGeofence: challengerAttendanceUseCase.isInsideGeofence,
            timeWindow: currentTimeWindow(for: session)
        )
    }

    /// 세션의 출석 정책 (`nil` = 아직 전달 전이거나 출석 비필수 일정)
    ///
    /// 시간대 판정과 같은 페이로드를 읽으므로, 화면이 보여주는 정책 시각과 실제 판정 기준이
    /// 어긋나지 않습니다. 정책 팝오버·출석 이력 카드가 표시용으로 사용합니다.
    func attendancePolicy(for sessionId: SessionID) -> ScheduleAttendancePolicy? {
        schedule(for: sessionId)?.attendancePolicy
    }

    // MARK: - Helper Methods

    /// 세션의 현재 출석 시간대
    ///
    /// 서버 출석 정책이 전달된 경우 정책 시각을 기준으로 판정하고,
    /// 아직 전달 전이면 UseCase 의 클라이언트 상수 기반 계산으로 폴백합니다.
    /// 정책과 상수가 다를 때(예: 지각 마감이 시작+30분보다 늦은 일정) 서버 정책이 우선입니다.
    private func currentTimeWindow(
        for session: Session,
        now: Date = Date()
    ) -> AttendanceTimeWindow {
        guard let policy = schedule(for: session.info.sessionId)?.attendancePolicy else {
            return challengerAttendanceUseCase.isWithinAttendanceTime(
                info: session.info,
                now: now
            )
        }

        if now < policy.checkInStartAt { return .tooEarly }
        if now <= policy.onTimeEndAt { return .onTime }
        if now <= policy.lateEndAt { return .lateWindow }
        return .expired
    }

    /// 마감까지 남은 시간 표시 (예: "7분 남음", "1시간 12분 남음")
    private func remainingText(until end: Date, from now: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(now) / 60))
        if minutes >= 60 {
            let remainder = minutes % 60
            return remainder == 0
                ? "\(minutes / 60)시간 남음"
                : "\(minutes / 60)시간 \(remainder)분 남음"
        }
        return "\(minutes)분 남음"
    }

    private func submitExcuse(
        timeWindow: AttendanceTimeWindow,
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        switch timeWindow {
        case .tooEarly, .onTime, .lateWindow:
            return try await challengerAttendanceUseCase.submitLateReason(
                sessionId: sessionId,
                userId: userId,
                reason: reason,
                scheduleId: scheduleId
            )
        case .expired:
            return try await challengerAttendanceUseCase.submitAbsentReason(
                sessionId: sessionId,
                userId: userId,
                reason: reason,
                scheduleId: scheduleId
            )
        }
    }

    // MARK: - Cleanup

    /// 지오펜스 모니터링 중지
    func geofenceCleanup() async {
        await challengerAttendanceUseCase.stopGeofenceMonitoring()
    }
}
