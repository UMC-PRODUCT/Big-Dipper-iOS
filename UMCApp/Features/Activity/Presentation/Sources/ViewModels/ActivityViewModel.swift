//
//  ActivityViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import Foundation
import HomeDomain
import UMCFoundation

/// Activity 탭 루트의 ViewModel
///
/// 출석 섹션이 소비하는 세션 목록과 출석 주체(`userId`)를 소유한다. 세션은 별도 API 가
/// 아니라 출석 가능 일정(`ChallengerAttendanceUseCaseProtocol.fetchAvailableSchedules()`)
/// 에서 파생한다 — 레거시의 `FetchSessionsUseCase` 는 #994 가 일정 조회로 흡수했다.
///
/// DIP 를 지켜 UseCase Protocol 에만 의존하므로, 테스트는 Mock 만으로 완결된다.
@MainActor
@Observable
final class ActivityViewModel {

    // MARK: - Dependencies (Protocol Only)

    private let challengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol
    private let fetchUserIdUseCase: FetchUserIdUseCaseProtocol
    private let classifyScheduleUseCase: ClassifyScheduleUseCaseProtocol

    // MARK: - State

    private(set) var sessionsState: Loadable<[Session]> = .idle
    private(set) var userId: UserID?

    // MARK: - Init

    init(
        challengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol,
        fetchUserIdUseCase: FetchUserIdUseCaseProtocol,
        classifyScheduleUseCase: ClassifyScheduleUseCaseProtocol
    ) {
        self.challengerAttendanceUseCase = challengerAttendanceUseCase
        self.fetchUserIdUseCase = fetchUserIdUseCase
        self.classifyScheduleUseCase = classifyScheduleUseCase
    }

    // MARK: - Action

    /// 탭 등장 시 로드 결정 메서드
    ///
    /// 첫 진입은 로딩 스피너와 함께 전체 로드하고, 재진입은 로딩 상태를 건드리지 않는 배경
    /// 갱신만 한다 (스피너가 끼면 자식 뷰가 파괴돼 펼침·지도 상태가 초기화된다).
    ///
    /// `userId` 를 세션보다 먼저 채우는 이유는 세션의 초기 출석 기록이 출석 주체를 요구하기
    /// 때문이다. 조회는 로컬 저장소 읽기라 네트워크 대기가 없어 순차 실행 비용이 없다.
    func load() async {
        if userId == nil {
            await fetchUserId()
        }

        if sessionsState.isIdle {
            await fetchSessions()
        } else {
            await refreshSessions()
        }
    }

    /// 세션 목록 조회 (로딩 스피너 표시, 재시도 버튼용)
    func fetchSessions() async {
        guard !sessionsState.isLoading else { return }
        let previous = sessionsState
        sessionsState = .loading
        do {
            let schedules = try await challengerAttendanceUseCase.fetchAvailableSchedules()
            sessionsState = .loaded(await makeSessions(from: schedules))
        } catch {
            sessionsState = state(after: error, previous: previous)
        }
    }

    /// 세션 목록 배경 갱신 (로딩 상태 변경 없음)
    ///
    /// 일정 멤버십(scheduleId 집합)이 그대로면 `sessionsState` 를 건드리지 않는다. `Session`
    /// 은 참조 타입이라 배열을 교체하면 제출 여부(`hasSubmitted`) 같은 로컬 상태가 새 인스턴스로
    /// 리셋되기 때문이다. 집합이 달라진 경우(일정 추가·삭제)에만 교체해 자식 `onChange` 를
    /// 트리거한다. 개별 세션의 출석 상태 동기화는 자식 화면의 폴링이 담당한다.
    func refreshSessions() async {
        guard !sessionsState.isLoading else { return }
        guard case .loaded(let current) = sessionsState else {
            // .idle/.failed 면 배경 갱신할 기준 목록이 없으므로 전체 조회로 대체한다.
            await fetchSessions()
            return
        }

        do {
            let schedules = try await challengerAttendanceUseCase.fetchAvailableSchedules()
            let currentIds = Set(current.map(\.id.value))
            let freshIds = Set(schedules.map(\.scheduleId))
            guard currentIds != freshIds else { return }
            sessionsState = .loaded(await makeSessions(from: schedules))
        } catch {
            // 배경 갱신 실패는 화면을 막지 않는다 (취소 포함). 기존 목록을 유지한다.
        }
    }

    /// 현재 사용자 식별자 조회
    ///
    /// 실패해도 세션 조회를 막지 않는다. 다만 세션의 초기 출석 기록에 출석 주체가 실리므로,
    /// 식별자가 세션보다 늦게(또는 다른 값으로) 도착하면 이미 만들어 둔 세션의 주체가
    /// 어긋난다. 그 경우에만 같은 일정으로 세션을 다시 만들어 주체를 바로잡는다.
    func fetchUserId() async {
        let previous = userId
        userId = try? await fetchUserIdUseCase.execute()

        guard userId != nil, userId != previous, sessionsState.value != nil else { return }
        await fetchSessions()
    }

    // MARK: - Function

    /// 일정 목록을 세션 목록으로 변환한다 (시작 시각 오름차순).
    ///
    /// 제목 분류는 중복 제목을 한 번만 계산해 캐시로 공유한다. 분류기 자체도 정규화 키 캐시를
    /// 갖지만, 같은 목록 안의 중복 호출까지 왕복시킬 이유가 없다.
    private func makeSessions(from schedules: [ScheduleDetailData]) async -> [Session] {
        let categories = await categories(for: schedules)
        return schedules
            .map { makeSession(from: $0, category: categories[$0.name] ?? .general) }
            .sorted { $0.info.startTime < $1.info.startTime }
    }

    /// 일정 제목별 분류 결과
    private func categories(
        for schedules: [ScheduleDetailData]
    ) async -> [String: ScheduleIconCategory] {
        var result: [String: ScheduleIconCategory] = [:]
        for title in Set(schedules.map(\.name)) {
            result[title] = await classifyScheduleUseCase.execute(title: title)
        }
        return result
    }

    /// 일정 하나를 세션으로 변환한다.
    ///
    /// - Note: `week` 는 일정 응답에 없는 값이라 0 으로 둔다. 주차 표기가 필요한 화면은
    ///   커리큘럼 쪽 모델을 쓴다.
    /// - Note: 비대면 일정(`location == nil`)은 좌표가 없어 (0, 0) 으로 둔다. 지오펜스는
    ///   출석 정책이 있는 대면 일정에만 등록되므로 판정에 쓰이지 않는다.
    private func makeSession(
        from data: ScheduleDetailData,
        category: ScheduleIconCategory
    ) -> Session {
        let sessionId = SessionID(value: data.scheduleId)
        let info = SessionInfo(
            sessionId: sessionId,
            category: category,
            iconName: category.rawValue,
            title: data.name,
            week: 0,
            startTime: data.startsAt,
            endTime: data.endsAt,
            location: Coordinate(
                latitude: data.location?.latitude ?? 0,
                longitude: data.location?.longitude ?? 0
            ),
            isAllDay: data.isAllDay
        )
        return Session(
            info: info,
            initialAttendance: makeAttendance(from: data, sessionId: sessionId)
        )
    }

    /// 일정에 실린 서버 출석 상태를 초기 출석 기록으로 옮긴다.
    ///
    /// 상태가 없거나(`nil`) 아직 출석 전이면 기록을 만들지 않는다 — 빈 기록을 넣으면 세션이
    /// "출석 전" 이 아니라 "조회된 미출석" 으로 보여 버튼 분기가 어긋난다.
    private func makeAttendance(
        from data: ScheduleDetailData,
        sessionId: SessionID
    ) -> Attendance? {
        guard let scheduleStatus = data.attendanceStatus else { return nil }
        let status = AttendanceStatus(scheduleStatus: scheduleStatus)
        guard status != .beforeAttendance else { return nil }

        return Attendance(
            sessionId: sessionId,
            userId: userId ?? UserID(value: ""),
            type: data.isAttendanceChecked ? .gps : .reason,
            status: status,
            locationVerification: nil,
            reason: nil
        )
    }

    /// 조회 실패 시 반영할 상태
    ///
    /// `.task` 라이프사이클 취소(`CancellationError`/`NSURLErrorCancelled`)는 실패가 아니므로
    /// `.failed` 로 전이시키지 않고 이전 상태로 되돌린다. 첫 진입에서 취소되면 `.idle` 로 남아
    /// 다음 등장 때 다시 조회한다. 형제 ViewModel(Home/Notice/MyPage·출석)의 취소 처리 관례와
    /// 동일하다.
    private func state(
        after error: Error,
        previous: Loadable<[Session]>
    ) -> Loadable<[Session]> {
        guard !error.isCancellation else { return previous }
        if let appError = error as? AppError { return .failed(appError) }
        if let domainError = error as? DomainError { return .failed(.domain(domainError)) }
        if let networkError = error as? NetworkError { return .failed(.network(networkError)) }
        if let repositoryError = error as? RepositoryError {
            return .failed(.repository(repositoryError))
        }
        return .failed(.unknown(message: error.localizedDescription))
    }
}
