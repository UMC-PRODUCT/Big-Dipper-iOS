//
//  ChallengerAttendanceViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 6/12/26.
//

import ActivityDomain
import Foundation
import UMCFoundation

/// 챌린저(일반 참여자)의 출석 관련 상태 및 액션을 관리하는 ViewModel
///
/// 출석 요청(GPS)·사유 제출·시간대 판정·지오펜스/권한 상태 등 액션·상태 로직은
/// `ChallengerAttendanceUseCaseProtocol` 에 연결되어 동작합니다.
/// 세션 목록/이력 로딩은 Schedule 모듈 이식 후 결선됩니다 (하단 TODO 스텁 참고).
@MainActor
@Observable
final class ChallengerAttendanceViewModel {

    // MARK: - Property

    private let errorHandler: ErrorHandler
    private let challengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol

    /// 출석 상태 변경 알림 관찰 토큰
    ///
    /// UI 관찰 대상이 아닌 내부 구현 세부사항이라 `@ObservationIgnored` 로 추적에서 제외합니다.
    /// deinit(nonisolated)에서 해제해야 하므로 `nonisolated(unsafe)` — init 1회 설정 + deinit
    /// 해제만이라 동시 접근이 없습니다.
    @ObservationIgnored
    private nonisolated(unsafe) var statusObserver: (any NSObjectProtocol)?

    /// 폴링 대상 세션 (View에서 주입)
    private var pollingSessions: [Session] = []

    /// 폴링 시 Session 상태 업데이트용 userId
    private var pollingUserId: UserID?

    /// 세션별 서버 출석 정책 캐시 (available schedules 조회 결과에서 추출)
    ///
    /// 시간대 판정(`timeWindow(for:now:)`)이 클라이언트 상수보다 서버 정책을
    /// 우선하도록 보관합니다. Schedule 모듈 결선 전까지는 비어 있습니다.
    private var schedulePolicies: [SessionID: ScheduleAttendancePolicy] = [:]

    /// 세션별 서버 일정 ID 캐시 (available schedules 조회 결과에서 추출)
    ///
    /// 출석·사유 제출 API가 요구하는 값입니다. Schedule 모듈 결선 전까지는 비어 있습니다.
    private var scheduleIds: [SessionID: String] = [:]

    /// 폴링 설정
    private enum PollingConfig {
        static let intervalSeconds: Int = 30
    }

    // MARK: - Init

    init(
        errorHandler: ErrorHandler,
        challengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol
    ) {
        self.errorHandler = errorHandler
        self.challengerAttendanceUseCase = challengerAttendanceUseCase
        observeAttendanceStatusChange()
    }

    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Notification

    private func observeAttendanceStatusChange() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .attendanceStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshMyHistory()
            }
        }
    }

    // MARK: - 세션 목록/이력 로딩 (Schedule 모듈 후행)

    // TODO: Schedule 모듈 이식 후 세션 목록/이력 로딩 결선 - [26.06.12] 이재원
    // — `ScheduleDetailData` 가 Schedule Feature 모듈에 정의 예정이라
    //   `ChallengerAttendanceUseCaseProtocol` 의 fetchAvailableSchedules / fetchMyHistory 와
    //   함께 동결됨 (PR #797 동결과 동일 사유).
    // — 결선 시 복원 대상: availableSchedules / myHistory Loadable 상태,
    //   syncSessionStates() 폴링 동기화, schedule(for:) 일정 매핑,
    //   updateSchedulePolicies(_:) 호출부.

    /// 화면 등장 시 로드 결정 메서드
    func loadOnAppear() async {
        // TODO: Schedule 모듈 이식 후 available schedules 시드 + 이력 로딩 복원 - [26.06.12] 이재원
    }

    /// 출석 가능 일정 갱신 (로딩 상태 변경 없이)
    func refreshAvailableSchedules() async {
        // TODO: Schedule 모듈 이식 후 fetchAvailableSchedules 결선 - [26.06.12] 이재원
    }

    /// 출석 이력 배경 갱신 (로딩 상태 변경 없이)
    private func refreshMyHistory() async {
        // TODO: Schedule 모듈 이식 후 fetchMyHistory 결선 - [26.06.12] 이재원
    }

    /// 출석 가능 일정 조회 (로딩 스피너 표시, .failed 재시도 버튼용)
    func fetchAvailableSchedules() async {
        // TODO: Schedule 모듈 이식 후 fetchAvailableSchedules 결선 - [26.06.12] 이재원
    }

    /// 내 출석 이력 조회 (로딩 스피너 표시, .failed 재시도 버튼용)
    func fetchMyHistory() async {
        // TODO: Schedule 모듈 이식 후 fetchMyHistory 결선 - [26.06.12] 이재원
    }

    /// 앱 foreground 복귀 시 전체 갱신 (두 API 병렬 호출)
    func refreshAfterForeground() async {
        async let schedules: Void = refreshAvailableSchedules()
        async let history: Void = refreshMyHistory()
        _ = await (schedules, history)
    }

    /// SessionID → scheduleId 매핑 (available schedules 기반)
    ///
    /// 값이 없으면 출석·사유 제출을 서버로 보낼 수 없으므로, 화면은 이 값이 `nil` 인 동안
    /// 액션 진입점을 비활성화해야 합니다.
    func scheduleId(for sessionId: SessionID) -> String? {
        scheduleIds[sessionId]
    }

    /// available schedules 조회 결과의 세션별 서버 일정 ID를 반영합니다.
    ///
    /// `updateSchedulePolicies(_:)` 와 같은 시점에 채워지는 짝입니다 — 정책만 있고 일정 ID가
    /// 없으면 시간대 판정은 되는데 제출은 못 하는 반쪽 상태가 됩니다.
    // TODO: Schedule 모듈 이식 후 refreshAvailableSchedules() 내부에서 호출하도록 결선 - [26.06.12] 이재원
    func updateScheduleIds(_ ids: [SessionID: String]) {
        scheduleIds = ids
    }

    /// 폴링으로 받은 서버 상태를 Session 객체에 동기화
    private func syncSessionStates() {
        // TODO: Schedule 모듈 이식 후 available schedules 상태 전파 복원 - [26.06.12] 이재원
        // — pollingSessions / pollingUserId 를 사용해 schedule 상태를 매칭합니다.
    }

    // MARK: - Polling

    /// 폴링에 필요한 세션 및 userId를 설정합니다.
    ///
    /// View 초기화 시 한 번 호출합니다.
    func configurePollingSessions(
        _ sessions: [Session],
        userId: UserID
    ) {
        self.pollingSessions = sessions
        self.pollingUserId = userId
    }

    /// 세션 진행 중일 때 주기적으로 상태를 갱신합니다.
    ///
    /// 진행 중인 세션이 있으면 즉시 1회 갱신한 뒤 간격을 두고 반복하므로,
    /// 화면 진입 직후 첫 갱신까지 대기 구간이 생기지 않습니다.
    /// `.task` 모디파이어에서 호출하면 뷰 사라질 때 자동 취소됩니다.
    /// 세션 시간 기반으로 진행 중 여부를 판단합니다.
    func startPollingIfNeeded(sessions: [Session]) async {
        // 공용 루프는 sleep-first 라, 문서화된 refresh-first 동작(진입 직후 대기 구간 없음)은
        // 루프 시작 전 1회 갱신으로 표현한다.
        guard !Task.isCancelled, hasActiveSession(in: sessions) else { return }
        await refreshAvailableSchedules()
        await refreshMyHistory()
        await PollingLoop.run(
            intervalSeconds: PollingConfig.intervalSeconds,
            while: { hasActiveSession(in: sessions) },
            refresh: {
                await refreshAvailableSchedules()
                await refreshMyHistory()
            }
        )
    }

    /// 진행 중인 세션이 하나라도 있는지 확인
    private func hasActiveSession(in sessions: [Session]) -> Bool {
        sessions.contains { session in
            let status = OperatorSessionStatus.from(
                startTime: session.info.startTime,
                endTime: session.info.endTime
            )
            return status == .inProgress
        }
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
    /// 정책 시각(available schedules)이 조회된 경우 마감 시각과 남은 시간을 함께 표시하고,
    /// 아직 조회 전이면 시간대 설명만 표시합니다. 만료 시간대는 버튼 문구가 대신하므로 nil.
    func attendanceGuidanceText(for session: Session, at now: Date) -> String? {
        guard session.attendanceStatus == .beforeAttendance else { return nil }

        let timeWindow = currentTimeWindow(for: session, now: now)
        let policy = schedulePolicies[session.info.sessionId]

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

    /// available schedules 조회 결과의 세션별 출석 정책을 반영합니다.
    ///
    /// 시간대 판정(`timeWindow(for:now:)`)이 서버 정책을 우선 사용하도록 캐시를 갱신합니다.
    // TODO: Schedule 모듈 이식 후 refreshAvailableSchedules() 내부에서 호출하도록 결선 - [26.06.12] 이재원
    func updateSchedulePolicies(_ policies: [SessionID: ScheduleAttendancePolicy]) {
        schedulePolicies = policies
    }

    /// 세션의 출석 정책 (`nil` = 아직 조회 전)
    ///
    /// 시간대 판정과 같은 캐시를 읽으므로, 화면이 보여주는 정책 시각과 실제 판정 기준이
    /// 어긋나지 않습니다. 정책 팝오버·출석 이력 카드가 표시용으로 사용합니다.
    func attendancePolicy(for sessionId: SessionID) -> ScheduleAttendancePolicy? {
        schedulePolicies[sessionId]
    }

    // MARK: - Helper Methods

    /// 세션의 현재 출석 시간대
    ///
    /// 서버 출석 정책(available schedules)이 조회된 경우 정책 시각을 기준으로 판정하고,
    /// 아직 조회 전이면 UseCase 의 클라이언트 상수 기반 계산으로 폴백합니다.
    /// 정책과 상수가 다를 때(예: 지각 마감이 시작+30분보다 늦은 일정) 서버 정책이 우선입니다.
    private func currentTimeWindow(
        for session: Session,
        now: Date = Date()
    ) -> AttendanceTimeWindow {
        guard let policy = schedulePolicies[session.info.sessionId] else {
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
