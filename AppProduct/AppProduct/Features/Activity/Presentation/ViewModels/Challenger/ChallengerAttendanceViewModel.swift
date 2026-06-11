//
//  ChallengerAttendanceViewModel.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/15/26.
//

import Foundation

/// 챌린저(일반 참여자)의 출석 관련 상태 및 액션을 관리하는 ViewModel
@Observable
final class ChallengerAttendanceViewModel {
    private var container: DIContainer
    private var errorHandler: ErrorHandler
    private var challengeAttendanceUseCase: ChallengerAttendanceUseCaseProtocol

    /// 출석 가능 일정 목록
    private(set) var availableSchedules: Loadable<[ScheduleDetailData]> = .idle

    /// 내 출석 이력
    private(set) var myHistory: Loadable<[ScheduleDetailData]> = .idle

    /// 재시도 중 여부 (RetryContentUnavailableView용)
    private(set) var isRetrying: Bool = false

    private var statusObserver: (any NSObjectProtocol)?

    /// 폴링 대상 세션 (View에서 주입)
    private var pollingSessions: [Session] = []

    /// 폴링 시 Session 상태 업데이트용 userId
    private var pollingUserId: UserID?

    /// 폴링 설정
    private enum PollingConfig {
        static let intervalSeconds: Int = 30
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

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        challengeAttendanceUseCase: ChallengerAttendanceUseCaseProtocol,
    ) {
        self.container = container
        self.errorHandler = errorHandler
        self.challengeAttendanceUseCase = challengeAttendanceUseCase
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

    /// 출석 이력 배경 갱신 (로딩 상태 변경 없이)
    @MainActor
    private func refreshMyHistory() async {
        guard !myHistory.isLoading else { return }
        do {
            let history = try await challengeAttendanceUseCase
                .fetchMyHistory()
            myHistory = .loaded(history)
        } catch {
            // 배경 갱신 실패는 무시
        }
    }

    /// 출석 가능 일정 갱신 (로딩 상태 변경 없이)
    ///
    /// onChange(sessions.map(\.id)) 에서도 호출하므로 internal로 노출합니다.
    @MainActor
    func refreshAvailableSchedules() async {
        guard !availableSchedules.isLoading else { return }
        do {
            let schedules = try await challengeAttendanceUseCase.fetchAvailableSchedules()
            availableSchedules = .loaded(schedules)
            syncSessionStates()
        } catch {
            // 배경 갱신 실패는 무시
        }
    }

    /// 화면 등장 시 로드 결정 메서드
    ///
    /// - availableSchedules가 .idle(첫 마운트): 네트워크 호출을 생략하고 .loaded([])로 시드합니다.
    ///   부모가 방금 같은 창으로 받아온 sessions prop을 표시하므로 자식의 payload는 불필요하며,
    ///   syncSessionStates()가 no-op이기 때문에 빈 배열로 시드해도 무해합니다.
    /// - .idle이 아닌 경우(재등장): availableSchedules는 refreshAvailableSchedules()로,
    ///   myHistory는 refreshMyHistory()로 배경 갱신합니다.
    @MainActor
    func loadOnAppear() async {
        if availableSchedules.isIdle {
            // 첫 마운트: availableSchedules 중복 호출 생략
            availableSchedules = .loaded([])
        } else {
            // 재등장: 배경 갱신 (로딩 스피너 없음)
            await refreshAvailableSchedules()
        }

        guard !Task.isCancelled else { return }

        if myHistory.isIdle {
            // 첫 마운트: 자식 고유 데이터이므로 정상 로딩 UI와 함께 fetch
            await fetchMyHistory()
        } else {
            // 재등장: 배경 갱신
            await refreshMyHistory()
        }
    }

    /// 폴링으로 받은 서버 상태를 Session 객체에 동기화
    ///
    /// `ScheduleDetailData.scheduleId`와
    /// `Session.id`를 매칭하여 상태를 전파합니다.
    @MainActor
    private func syncSessionStates() {
        guard case .loaded(let schedules) = availableSchedules,
              let userId = pollingUserId else { return }

        let scheduleMap: [String: AttendanceStatus] = Dictionary(
            uniqueKeysWithValues: schedules.map {
                (String($0.scheduleId), $0.attendanceStatus ?? .beforeAttendance)
            }
        )

        for session in pollingSessions {
            if let serverStatus = scheduleMap[session.id.value] {
                session.updateStatusFromPolling(
                    serverStatus,
                    userId: userId
                )
            }
        }
    }

    /// 앱 foreground 복귀 시 전체 갱신 (두 API 병렬 호출)
    @MainActor
    func refreshAfterForeground() async {
        async let schedules: Void = refreshAvailableSchedules()
        async let history: Void = refreshMyHistory()
        _ = await (schedules, history)
    }

    /// 폴링에 필요한 세션 및 userId를 설정합니다.
    ///
    /// View 초기화 시 한 번 호출합니다.
    @MainActor
    func configurePollingSessions(
        _ sessions: [Session],
        userId: UserID
    ) {
        self.pollingSessions = sessions
        self.pollingUserId = userId
    }

    /// 세션 진행 중일 때 주기적으로 상태를 갱신합니다.
    ///
    /// `.task` 모디파이어에서 호출하면 뷰 사라질 때
    /// 자동 취소됩니다.
    /// 세션 시간 기반으로 진행 중 여부를 판단합니다.
    @MainActor
    func startPollingIfNeeded(sessions: [Session]) async {
        while !Task.isCancelled {
            guard hasActiveSession(in: sessions) else { return }
            try? await Task.sleep(for: .seconds(
                PollingConfig.intervalSeconds
            ))
            guard !Task.isCancelled else { break }
            await refreshAvailableSchedules()
            await refreshMyHistory()
        }
    }

    // MARK: - Action

    /// 출석 가능 일정 조회 (로딩 스피너 표시, .failed 재시도 버튼용)
    @MainActor
    func fetchAvailableSchedules() async {
        availableSchedules = .loading
        do {
            let schedules = try await challengeAttendanceUseCase.fetchAvailableSchedules()
            availableSchedules = .loaded(schedules)
            syncSessionStates()
        } catch {
            // 취소는 .idle로 되돌려 다음 등장 시 재시도 — .failed로 에러 UI를 표시하지 않음
            if error.isCancellation {
                availableSchedules = .idle
            } else {
                availableSchedules = .failed(.unknown(
                    message: error.localizedDescription
                ))
            }
        }
    }

    /// 내 출석 이력 조회 (로딩 스피너 표시, .failed 재시도 버튼용)
    @MainActor
    func fetchMyHistory() async {
        myHistory = .loading
        do {
            let history = try await challengeAttendanceUseCase.fetchMyHistory()
            myHistory = .loaded(history)
        } catch {
            // 취소는 .idle로 되돌려 다음 등장 시 재시도 — .failed로 에러 UI를 표시하지 않음
            if error.isCancellation {
                myHistory = .idle
            } else {
                myHistory = .failed(.unknown(
                    message: error.localizedDescription
                ))
            }
        }
    }

    /// GPS 기반 출석 버튼 탭 처리
    @MainActor
    func attendanceBtnTapped(userId: UserID, session: Session, scheduleId: Int) async {
        let info = session.info
        let timeWindow = currentTimeWindow(for: info)

        #if DEBUG
        print("[Attendance] attendanceBtnTapped called")
        print("[Attendance] timeWindow: \(timeWindow)")
        print("[Attendance] info.startTime: \(info.startTime)")
        print("[Attendance] now: \(Date())")
        #endif

        // .onTime = 정시 출석 가능 시간대
        guard timeWindow == .onTime else {
            #if DEBUG
            print("[Attendance] Guard failed - not in onTime window")
            #endif
            return
        }

        session.updateState(.loading)

        do {
            let result = try await challengeAttendanceUseCase.requestGPSAttendance(
                sessionId: info.sessionId, userId: userId, scheduleId: scheduleId)
            session.updateState(.loaded(result))
            session.markSubmitted()

        } catch let error as DomainError {
            session.updateState(.failed(.domain(error)))
        } catch {
            // 기타 에러 (네트워크 등) — 상태 복구 후 Alert
            if let prev = session.attendance {
                session.updateState(.loaded(prev))
            } else {
                session.updateState(.idle)
            }
            errorHandler.handle(error, context: .init(
                feature: "Activity",
                action: "attendanceBtnTapped",
                retryAction: { [weak self] in
                    await self?.attendanceBtnTapped(userId: userId, session: session, scheduleId: scheduleId)
                }
            ))
        }
    }

    /// 지각/결석 사유 제출 버튼 탭 처리
    @MainActor
    func attendanceReasonBtnTapped(
        userId: UserID,
        session: Session,
        reason: String,
        scheduleId: Int
    ) async {
        let info = session.info
        let timeWindow = currentTimeWindow(for: info)

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

        } catch let error as DomainError {
            session.updateState(.failed(.domain(error)))
        } catch {
            // 기타 에러 (네트워크 등) — 상태 복구 후 Alert
            if let attendance = session.attendance {
                session.updateState(.loaded(attendance))
            } else {
                session.updateState(.idle)
            }
            errorHandler.handle(error, context: .init(
                feature: "Activity",
                action: "attendanceReasonBtnTapped",
                retryAction: { [weak self] in
                    await self?.attendanceReasonBtnTapped(
                        userId: userId,
                        session: session,
                        reason: reason,
                        scheduleId: scheduleId
                    )
                }
            ))
        }
    }

    /// 출석 사유 제출
    ///
    /// GPS 출석이 어려운 경우 사유를 제출합니다.
    /// - Parameters:
    ///   - userId: 사용자 ID
    ///   - session: 출석 대상 세션
    ///   - reason: 출석 사유
    ///   - scheduleId: 일정 ID (V2)
    @MainActor
    func submitAttendanceReason(
        userId: UserID,
        session: Session,
        reason: String,
        scheduleId: Int
    ) async {
        let info = session.info
        let timeWindow = currentTimeWindow(for: info)
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
            if let prev = session.attendance {
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

    /// SessionID → scheduleId 매핑 (available schedules 기반)
    func scheduleId(for sessionId: SessionID) -> Int? {
        guard case .loaded(let schedules) = availableSchedules else {
            return nil
        }
        return schedules.first(where: {
            String($0.scheduleId) == sessionId.value
        })?.scheduleId
    }

    func isAttendanceAvailable(for session: Session) -> Bool {
        session.canRequestAttendance(
            timeWindow: currentTimeWindow(for: session.info),
            isInsideGeofence: challengeAttendanceUseCase.isInsideGeofence,
            isLocationAuthorized: challengeAttendanceUseCase.isLocationAuthorized
        )
    }

    func isReasonSubmittable(for session: Session) -> Bool {
        session.canSubmitReason()
    }

    func shouldShowReasonButton(for session: Session) -> Bool {
        currentTimeWindow(for: session.info) != .expired
    }

    func buttonStyle(for session: Session) -> String {
        session.buttonTitle(
            isLocationAuthorized: challengeAttendanceUseCase.isLocationAuthorized,
            isInsideGeofence: challengeAttendanceUseCase.isInsideGeofence,
            timeWindow: challengeAttendanceUseCase.isWithinAttendanceTime(info: session.info)
        )
    }

    // MARK: - Helper Methods

    private func currentTimeWindow(for info: SessionInfo) -> AttendanceTimeWindow {
        challengeAttendanceUseCase.isWithinAttendanceTime(info: info)
    }

    private func submitExcuse(
        timeWindow: AttendanceTimeWindow,
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: Int
    ) async throws -> Attendance {
        switch timeWindow {
        case .tooEarly, .onTime, .lateWindow:
            return try await challengeAttendanceUseCase.submitLateReason(
                sessionId: sessionId,
                userId: userId,
                reason: reason,
                scheduleId: scheduleId
            )
        case .expired:
            return try await challengeAttendanceUseCase.submitAbsentReason(
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
        await challengeAttendanceUseCase.stopGeofenceMonitoring()
    }
}
