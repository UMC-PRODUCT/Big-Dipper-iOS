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
/// 출석 요청(GPS)·사유 제출·시간대 판정·지오펜스/권한 상태와 함께, 출석 가능 일정 목록과
/// 내 출석 이력을 `ChallengerAttendanceUseCaseProtocol` 로 조회합니다.
@MainActor
@Observable
final class ChallengerAttendanceViewModel {

    // MARK: - Property

    private let errorHandler: ErrorHandler
    private let challengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol

    /// 출석 가능 일정 목록
    private(set) var availableSchedules: Loadable<[ScheduleDetailData]> = .idle

    /// 내 출석 이력
    private(set) var myHistory: Loadable<[ScheduleDetailData]> = .idle

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

    // MARK: - 세션 목록/이력 로딩

    /// 화면 등장 시 로드 결정 메서드
    ///
    /// - `availableSchedules` 가 `.idle`(첫 마운트)이면 부모가 넘긴 sessions prop 이 즉시
    ///   렌더되도록 `.loaded([])` 로 먼저 시드한 뒤 배경 갱신으로 페이로드를 채웁니다.
    ///   페이로드는 출석 버튼의 `scheduleId` 조회와 서버 정책 기반 시간대 판정에 필요합니다.
    /// - 재등장 시에는 두 목록 모두 로딩 스피너 없이 배경 갱신만 합니다.
    func loadOnAppear() async {
        if availableSchedules.isIdle {
            availableSchedules = .loaded([])
        }
        await refreshAvailableSchedules()

        guard !Task.isCancelled else { return }

        if myHistory.isIdle {
            // 첫 마운트: 자식 화면 고유 데이터라 정상 로딩 UI와 함께 조회
            await fetchMyHistory()
        } else {
            await refreshMyHistory()
        }
    }

    /// 출석 가능 일정 갱신 (로딩 상태 변경 없이)
    ///
    /// 세션 목록 변화(`onChange`)와 폴링에서도 호출하므로 internal 로 노출합니다.
    func refreshAvailableSchedules() async {
        guard !availableSchedules.isLoading else { return }
        do {
            let schedules = try await challengerAttendanceUseCase.fetchAvailableSchedules()
            availableSchedules = .loaded(schedules)
            syncSessionStates()
        } catch {
            // 배경 갱신 실패는 화면을 막지 않는다 (취소 포함). 기존 목록을 유지한다.
        }
    }

    /// 출석 이력 배경 갱신 (로딩 상태 변경 없이)
    private func refreshMyHistory() async {
        guard !myHistory.isLoading else { return }
        do {
            let history = try await challengerAttendanceUseCase.fetchMyHistory()
            myHistory = .loaded(history)
        } catch {
            // 배경 갱신 실패는 화면을 막지 않는다 (취소 포함). 기존 이력을 유지한다.
        }
    }

    /// 출석 가능 일정 조회 (로딩 스피너 표시, `.failed` 재시도 버튼용)
    func fetchAvailableSchedules() async {
        guard !availableSchedules.isLoading else { return }
        let previous = availableSchedules
        availableSchedules = .loading
        do {
            let schedules = try await challengerAttendanceUseCase.fetchAvailableSchedules()
            availableSchedules = .loaded(schedules)
            syncSessionStates()
        } catch {
            availableSchedules = state(after: error, previous: previous)
        }
    }

    /// 내 출석 이력 조회 (로딩 스피너 표시, `.failed` 재시도 버튼용)
    func fetchMyHistory() async {
        guard !myHistory.isLoading else { return }
        let previous = myHistory
        myHistory = .loading
        do {
            let history = try await challengerAttendanceUseCase.fetchMyHistory()
            myHistory = .loaded(history)
        } catch {
            myHistory = state(after: error, previous: previous)
        }
    }

    /// 앱 foreground 복귀 시 전체 갱신 (두 API 병렬 호출)
    func refreshAfterForeground() async {
        async let schedules: Void = refreshAvailableSchedules()
        async let history: Void = refreshMyHistory()
        _ = await (schedules, history)
    }

    /// SessionID → 일정 매핑 (available schedules 기반)
    ///
    /// 첫 마운트에는 `loadOnAppear()` 가 빈 배열로 시드하므로 `nil` 일 수 있습니다.
    /// 호출 측은 `nil` 이면 `refreshAvailableSchedules()` 로 페이로드를 채웁니다.
    func schedule(for sessionId: SessionID) -> ScheduleDetailData? {
        guard case .loaded(let schedules) = availableSchedules else { return nil }
        return schedules.first { $0.scheduleId == sessionId.value }
    }

    /// SessionID → scheduleId 매핑 (available schedules 기반)
    func scheduleId(for sessionId: SessionID) -> String? {
        schedule(for: sessionId)?.scheduleId
    }

    /// 조회된 서버 상태를 폴링 대상 Session 객체에 동기화
    ///
    /// `ScheduleDetailData.scheduleId` 와 `Session.id` 를 맞춰 상태를 전파합니다.
    ///
    /// 서버가 `attendanceStatus` 를 안 내려준 일정(`nil`)은 건너뜁니다. `nil` 은 "출석 전"
    /// 이라는 판정이 아니라 정보 없음이므로, 이를 `.beforeAttendance` 로 치환하면 방금 제출해
    /// 지각/승인 대기로 올라간 로컬 상태를 되돌려 버립니다.
    private func syncSessionStates() {
        guard case .loaded(let schedules) = availableSchedules,
              let userId = pollingUserId else { return }

        let statusByScheduleId: [String: AttendanceStatus] = schedules.reduce(into: [:]) {
            partialResult, schedule in
            guard let status = schedule.attendanceStatus else { return }
            partialResult[schedule.scheduleId] = AttendanceStatus(scheduleStatus: status)
        }

        for session in pollingSessions {
            guard let serverStatus = statusByScheduleId[session.id.value] else { continue }
            session.updateStatusFromPolling(serverStatus, userId: userId)
        }
    }

    /// 조회 실패 시 반영할 상태
    ///
    /// `.task` 라이프사이클 취소(빠른 화면 이탈·탭 전환)는 실패가 아니므로 `.failed` 로
    /// 전이시키지 않고 이전 상태로 되돌립니다. 첫 마운트에서 취소되면 `.idle` 로 남아
    /// 다음 등장 때 다시 조회합니다. 형제 ViewModel(Home/Notice/MyPage)의 취소 처리 관례와
    /// 동일합니다.
    private func state(
        after error: Error,
        previous: Loadable<[ScheduleDetailData]>
    ) -> Loadable<[ScheduleDetailData]> {
        guard !error.isCancellation else { return previous }
        if let appError = error as? AppError { return .failed(appError) }
        if let domainError = error as? DomainError { return .failed(.domain(domainError)) }
        return .failed(.unknown(message: error.localizedDescription))
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

    /// 세션의 출석 정책 (`nil` = 아직 조회 전이거나 출석 비필수 일정)
    ///
    /// 시간대 판정과 같은 페이로드를 읽으므로, 화면이 보여주는 정책 시각과 실제 판정 기준이
    /// 어긋나지 않습니다. 정책 팝오버·출석 이력 카드가 표시용으로 사용합니다.
    func attendancePolicy(for sessionId: SessionID) -> ScheduleAttendancePolicy? {
        schedule(for: sessionId)?.attendancePolicy
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

#if DEBUG

extension ChallengerAttendanceViewModel {

    /// 프리뷰 전용 — 네트워크 조회 없이 일정 페이로드를 적재합니다.
    ///
    /// 일정 ID·출석 정책은 모두 `availableSchedules` 에서 파생되므로, 프리뷰도 실제 조회가
    /// 채우는 것과 같은 상태를 세팅해야 화면이 프로덕션과 같은 분기를 탑니다.
    /// (별도 캐시를 두면 프리뷰만 통과하고 실제 화면은 비는 상태가 만들어집니다.)
    func seedSchedulesForPreview(_ schedules: [ScheduleDetailData]) {
        availableSchedules = .loaded(schedules)
    }
}

#endif
