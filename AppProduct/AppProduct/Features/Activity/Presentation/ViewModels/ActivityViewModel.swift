//
//  ActivityViewModel.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/25/26.
//

import Foundation

/// Activity Feature 메인 화면의 ViewModel
///
/// DIP를 준수하여 UseCase Protocol만 주입받습니다.
@Observable
final class ActivityViewModel {

    // MARK: - Dependencies (Protocol Only)

    private let fetchSessionsUseCase: FetchSessionsUseCaseProtocol
    private let fetchUserIdUseCase: FetchUserIdUseCaseProtocol
    private let classifyScheduleUseCase: ClassifyScheduleUseCase

    // MARK: - State

    private(set) var sessionsState: Loadable<[Session]> = .idle
    private(set) var userId: UserID?
    private(set) var categoryCache: [String: ScheduleIconCategory] = [:]

    // MARK: - Init

    init(
        fetchSessionsUseCase: FetchSessionsUseCaseProtocol,
        fetchUserIdUseCase: FetchUserIdUseCaseProtocol,
        classifyScheduleUseCase: ClassifyScheduleUseCase
    ) {
        self.fetchSessionsUseCase = fetchSessionsUseCase
        self.fetchUserIdUseCase = fetchUserIdUseCase
        self.classifyScheduleUseCase = classifyScheduleUseCase
    }

    // MARK: - Action

    /// 세션 목록 조회 (로딩 스피너 표시, 재시도 버튼용)
    @MainActor
    func fetchSessions() async {
        sessionsState = .loading
        do {
            let sessions = try await fetchSessionsUseCase.execute()
            await classifySessionTitles(sessions)
            sessionsState = .loaded(sessions)
        } catch let error as DomainError {
            sessionsState = .failed(.domain(error))
        } catch {
            sessionsState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 세션 목록 배경 갱신 (로딩 상태 변경 없음, 재진입 시 자식 뷰 파괴 방지)
    ///
    /// 일정 멤버십(scheduleId 집합)이 변하지 않으면 sessionsState를 건드리지 않습니다.
    /// 집합이 달라진 경우에만 .loaded(새 배열)로 교체하여 자식 onChange를 트리거합니다.
    @MainActor
    func refreshSessions() async {
        guard !sessionsState.isLoading else { return }
        do {
            let fresh = try await fetchSessionsUseCase.execute()
            guard case .loaded(let current) = sessionsState else {
                // .idle/.failed 상태면 full fetch로 대체
                await fetchSessions()
                return
            }
            let currentIds = Set(current.map(\.id.value))
            let freshIds = Set(fresh.map(\.id.value))
            guard currentIds != freshIds else { return }
            await classifySessionTitles(fresh)
            sessionsState = .loaded(fresh)
        } catch {
            // 배경 갱신 실패는 무시 — 기존 표시 상태 유지
        }
    }

    /// 사용자 ID 조회
    @MainActor
    func fetchUserId() async {
        userId = try? await fetchUserIdUseCase.execute()
    }

    /// 초기 데이터 로드
    @MainActor
    func loadInitialData() async {
        async let sessionsTask: () = fetchSessions()
        async let userIdTask: () = fetchUserId()
        _ = await (sessionsTask, userIdTask)
    }

    // MARK: - Classification

    /// 세션 제목들을 병렬로 분류하여 캐시에 저장
    @MainActor
    private func classifySessionTitles(_ sessions: [Session]) async {
        await withTaskGroup(of: (String, ScheduleIconCategory).self) { group in
            // 중복 제거된 타이틀만 분류
            let uniqueTitles = Set(sessions.map { $0.info.title })

            for title in uniqueTitles {
                group.addTask {
                    let category = await self.classifyScheduleUseCase.execute(
                        title: title
                    )
                    return (title, category)
                }
            }

            for await (title, category) in group {
                categoryCache[title] = category
            }
        }
    }

    /// 제목에 해당하는 카테고리 반환 (캐시에 없으면 .general)
    func category(for title: String) -> ScheduleIconCategory {
        categoryCache[title] ?? .general
    }

}
