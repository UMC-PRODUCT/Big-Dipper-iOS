//
//  HomeViewModel.swift
//  HomePresentation
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDI
import CoreDomain
import Foundation
import HomeDomain
import NoticeDomain
import UMCFoundation
import os.log

private let logger = Logger(subsystem: "UMCApp", category: "Home")

/// 홈 화면(시즌/세대 카드/최근 공지/일정 캘린더) ViewModel
@Observable
@MainActor
public final class HomeViewModel {

    // MARK: - Property

    public private(set) var seasonState: Loadable<[SeasonType]> = .idle
    public private(set) var generationState: Loadable<[HomeGeneration]> = .idle
    public private(set) var recentNoticeState: Loadable<[NoticeItemModel]> = .idle

    /// 선택 월의 일정을 KST 자정 기준 날짜로 그룹핑한 딕셔너리.
    ///
    /// 캘린더는 조회 실패 시에도 화면 흐름을 막지 않아야 하므로 `Loadable`로 감싸지 않고,
    /// 실패 시 빈 딕셔너리로 degrade한다 (원본 AppProduct와 동일한 정책).
    public private(set) var scheduleByDates: [Date: [ScheduleDetailData]] = [:]

    /// 일정 ID(``ScheduleDetailData/scheduleId``) → 분류된 카테고리. 현재 로드된 일정만 담으며
    /// (월 이동/조회 실패 시 ``scheduleByDates`` 와 동일하게 정리된다),
    /// 조회는 ``category(for:)`` 를 통해 기본값(``ScheduleIconCategory/general``)과 함께 사용한다.
    public private(set) var scheduleCategories: [String: ScheduleIconCategory] = [:]

    /// 일정이 있는 날짜 집합 (캘린더 그리드의 점 표시용).
    public var scheduleDates: Set<Date> {
        Set(scheduleByDates.keys)
    }

    /// 진행 중인 일정 조회/분류 작업의 세대. 월 이동이나 초기화로 요청이 새로 시작되면 증가시켜,
    /// 뒤늦게 도착한 이전 달 결과가 현재 화면을 덮어쓰지 않게 한다.
    /// 뷰가 읽지 않는 내부 상태이므로 관찰 대상에서 제외한다.
    @ObservationIgnored
    private var scheduleRequestGeneration = 0

    private let fetchMyProfileUseCase: FetchHomeProfileUseCaseProtocol
    private let fetchRecentNoticesUseCase: FetchRecentNoticesUseCaseProtocol
    private let fetchMySchedulesUseCase: FetchSchedulesUseCaseProtocol
    private let classifyScheduleUseCase: ClassifyScheduleUseCaseProtocol
    private let challengerGenRepository: ChallengerGenRepositoryProtocol
    private let fetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol
    private let syncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol

    // MARK: - Init

    public init(container: DIContainer) {
        fetchMyProfileUseCase = container.resolve(FetchHomeProfileUseCaseProtocol.self)
        fetchRecentNoticesUseCase = container.resolve(FetchRecentNoticesUseCaseProtocol.self)
        fetchMySchedulesUseCase = container.resolve(FetchSchedulesUseCaseProtocol.self)
        classifyScheduleUseCase = container.resolve(ClassifyScheduleUseCaseProtocol.self)
        challengerGenRepository = container.resolve(ChallengerGenRepositoryProtocol.self)
        fetchMemberProfileUseCase = container.resolve(FetchMemberProfileUseCaseProtocol.self)
        syncProfileStorageUseCase = container.resolve(SyncProfileStorageUseCaseProtocol.self)
    }

    // MARK: - Function

    /// 아직 로딩을 시작하지 않았을 때만 프로필을 조회한다. `.task`의 최초 트리거로 사용한다.
    public func fetchProfileIfNeeded() async {
        guard seasonState.isIdle else { return }
        await fetchProfile()
    }

    /// 내 프로필을 조회해 시즌/세대 카드 상태를 갱신한다. 실패 시 인라인 `.failed` 상태로 표시한다.
    /// 세대 조회가 성공하면 최신 기수를 기준으로 최근 공지도 함께 조회한다.
    /// - Parameter forceRefresh: `true`이면 세션 프로필 캐시를 우회해 서버 최신으로 갱신한다
    ///   (당겨서 새로고침 경로).
    public func fetchProfile(forceRefresh: Bool = false) async {
        if seasonState.isLoading { return }

        let previousSeasonState = seasonState
        let previousGenerationState = generationState
        seasonState = .loading
        generationState = .loading

        do {
            let profile = try await fetchMyProfileUseCase.execute(forceRefresh: forceRefresh)
            let sortedGenerations = sortedByGenerationDescending(profile.generations)
            seasonState = .loaded(profile.seasonTypes)
            generationState = .loaded(sortedGenerations)
            syncGenerationMappings(sortedGenerations)
            await syncProfileStorage()
            await fetchRecentNotices(latestGisuId: sortedGenerations.first?.gisuId)
        } catch is CancellationError {
            seasonState = previousSeasonState
            generationState = previousGenerationState
        } catch let error as RepositoryError {
            setFailed(.repository(error))
        } catch let error as NetworkError {
            setFailed(.network(error))
        } catch let error as AppError {
            setFailed(error)
        } catch {
            setFailed(.unknown(message: error.localizedDescription))
        }
    }

    /// 최근 공지 섹션의 재시도 진입점.
    ///
    /// 최근 공지는 프로필의 최신 기수에 종속되므로, 기수 정보가 아직 없으면(프로필 조회 실패 등)
    /// 프로필부터 다시 받아야 재조회가 의미를 가진다.
    public func retryRecentNotices() async {
        guard case .loaded(let generations) = generationState,
              let latestGisuId = generations.first?.gisuId else {
            await fetchProfile()
            return
        }
        await fetchRecentNotices(latestGisuId: latestGisuId)
    }

    /// 월별 일정 조회 (KST 기준 월초/월말로 변환해 V2 일정 목록 API를 호출한다).
    ///
    /// 캘린더는 출석 필수 여부와 무관한 모든 일정을 보여줘야 하므로
    /// `isAttendanceRequired: false`로 고정 호출한다.
    ///
    /// - Parameters:
    ///   - year: 조회 연도 (nil이면 현재 연도, KST 기준)
    ///   - month: 조회 월 (nil이면 현재 월, KST 기준)
    public func fetchSchedules(year: Int? = nil, month: Int? = nil) async {
        let calendar = Calendar.kstGregorian
        let now = Date()
        let targetYear = year ?? calendar.component(.year, from: now)
        let targetMonth = month ?? calendar.component(.month, from: now)

        scheduleRequestGeneration += 1
        let generation = scheduleRequestGeneration

        guard
            let startOfMonth = calendar.date(from: DateComponents(year: targetYear, month: targetMonth, day: 1)),
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
        else {
            clearSchedules()
            return
        }

        do {
            let schedules = try await fetchMySchedulesUseCase.execute(
                from: startOfMonth.kstStartOfDay,
                to: endOfMonth.kstEndOfDay,
                isAttendanceRequired: false
            )
            guard generation == scheduleRequestGeneration else { return }
            scheduleByDates = schedules
            await classifySchedules(schedules.values.flatMap { $0 }, generation: generation)
        } catch {
            guard generation == scheduleRequestGeneration else { return }
            clearSchedules()
        }
    }

    /// 특정 날짜(KST 자정 기준 정규화)에 해당하는 일정 목록을 반환한다.
    public func getSchedules(_ date: Date) -> [ScheduleDetailData] {
        scheduleByDates[Calendar.kstGregorian.startOfDay(for: date)] ?? []
    }

    /// 일정 ID로 분류된 카테고리를 조회한다. 분류 전/실패 시 ``ScheduleIconCategory/general``.
    public func category(for scheduleId: String) -> ScheduleIconCategory {
        scheduleCategories[scheduleId] ?? .general
    }

    /// 주어진 일정들의 아이콘 분류가 모두 끝났는지 여부.
    ///
    /// 분류 전에는 전부 `.general`로 그려졌다가 아이콘이 뒤늦게 바뀌는 깜빡임이 생기므로, 뷰는
    /// 이 값으로 리스트 렌더를 잠깐 보류한다. 화면에 실제로 보이는 일정만 넘겨야 한다 —
    /// 월 전체를 기준으로 잡으면 첫 렌더가 그만큼 늦어진다.
    public func areCategoriesReady(for schedules: [ScheduleDetailData]) -> Bool {
        schedules.allSatisfy { scheduleCategories[$0.scheduleId] != nil }
    }

    // MARK: - Private Function

    /// 정본 프로필을 로컬 저장소(`UserDefaults`/`UserSessionManager`)에 반영한다.
    ///
    /// 역할·기수·지부 등 다른 탭이 `AppStorageKey`로 읽는 값들은 로그인 시점에만 기록되므로,
    /// 세션 도중 서버에서 바뀐 정보(역할 승격 등)는 홈 진입 때 다시 맞춰줘야 한다.
    /// 홈 프로필 조회가 이미 세션 캐시를 채운 뒤이므로 여기서 추가 왕복은 발생하지 않는다.
    /// 동기화 실패는 홈 표시에 치명적이지 않으므로 로그만 남긴다.
    private func syncProfileStorage() async {
        do {
            let profile = try await fetchMemberProfileUseCase.execute()
            syncProfileStorageUseCase.execute(profile: profile)
        } catch {
            logger.error("프로필 로컬 저장 동기화 실패: \(error.localizedDescription)")
        }
    }

    /// 프로필의 기수 목록을 (gen, gisuId) 로컬 매핑에 반영하고 갱신을 브로드캐스트한다.
    /// 공지 탭이 기수 필터를 이 매핑으로 구성하므로, 홈 프로필 조회가 유일한 생산자다.
    ///
    /// 저장 실패는 홈 화면 표시에 치명적이지 않으므로 `Loadable` 상태를 깨지 않고 로그만 남긴다.
    private func syncGenerationMappings(_ generations: [HomeGeneration]) {
        do {
            try challengerGenRepository.replaceMappings(
                generations.map { (gen: $0.gen, gisuId: $0.gisuId) }
            )
            NotificationCenter.default.post(name: .generationMappingsUpdated, object: nil)
        } catch {
            logger.error("기수 매핑 동기화 실패: \(error.localizedDescription)")
        }
    }

    /// 일정 제목을 분류해 ``scheduleCategories`` 를 갱신한다. 빈 제목이거나 분류가 실패해도
    /// UseCase가 `.general`을 반환하므로 별도 에러 처리는 필요 없다.
    ///
    /// 결과는 로컬 딕셔너리에 누적한 뒤 한 번만 할당한다. 뷰 무효화가 일정 수만큼 쪼개지는 것을
    /// 막고, 현재 일정 집합으로 새로 구성하므로 이전 달 분류 결과가 함께 pruning된다.
    ///
    /// 분류는 일정마다 독립적이므로 병렬로 돌린다 — 순차 처리하면 CoreML 추론 지연이 일정 수만큼
    /// 누적돼 리스트 첫 렌더가 그만큼 밀린다.
    private func classifySchedules(
        _ schedules: [ScheduleDetailData],
        generation: Int
    ) async {
        // UseCase 프로토콜에 `Sendable` 표기가 없지만, 구현체의 분류 캐시는 락으로 보호되고
        // CoreML 추론도 동시 호출이 안전하므로 병렬 태스크로 넘겨도 된다.
        nonisolated(unsafe) let useCase = classifyScheduleUseCase

        var categories: [String: ScheduleIconCategory] = [:]
        await withTaskGroup(of: (String, ScheduleIconCategory).self) { group in
            for schedule in schedules {
                group.addTask {
                    let category = await useCase.execute(title: schedule.name)
                    return (schedule.scheduleId, category)
                }
            }

            for await (scheduleId, category) in group {
                categories[scheduleId] = category
            }
        }

        guard generation == scheduleRequestGeneration else { return }
        scheduleCategories = categories
    }

    /// 일정 조회가 불가능하거나 실패했을 때의 degrade 처리. 캘린더는 흐름을 막지 않아야 하므로
    /// 일정과 분류 결과를 함께 비운다 (UseCase 레이어의 분류 캐시는 유지된다).
    private func clearSchedules() {
        scheduleRequestGeneration += 1
        scheduleByDates = [:]
        scheduleCategories = [:]
    }

    /// 최신 기수의 최근 공지 5건을 조회한다. 소속 기수가 없으면 빈 목록으로 처리한다.
    ///
    /// 프로필 응답에 기수가 비어 있어도 직전 세션에서 저장된 기수가 남아 있으면 공지를 보여줄 수
    /// 있으므로, 로컬 저장값을 폴백으로 쓴다.
    private func fetchRecentNotices(latestGisuId: String?) async {
        let resolvedGisuId = latestGisuId.flatMap { $0.isEmpty ? nil : $0 }
            ?? AppStorageKey.gisuIdString()
        guard let gisuId = resolvedGisuId else {
            recentNoticeState = .loaded([])
            return
        }

        recentNoticeState = .loading

        do {
            let notices = try await fetchRecentNoticesUseCase.execute(gisuId: gisuId)
            recentNoticeState = .loaded(notices)
        } catch is CancellationError {
            recentNoticeState = .idle
        } catch let error as RepositoryError {
            recentNoticeState = .failed(.repository(error))
        } catch let error as NetworkError {
            recentNoticeState = .failed(.network(error))
        } catch let error as AppError {
            recentNoticeState = .failed(error)
        } catch {
            recentNoticeState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    private func setFailed(_ error: AppError) {
        seasonState = .failed(error)
        generationState = .failed(error)
        recentNoticeState = .failed(error)
    }

    /// 기수(`gen`)는 서버 정수를 `String`으로 보존하므로 정렬 시점에만 `Int`로 환원한다.
    private func sortedByGenerationDescending(_ generations: [HomeGeneration]) -> [HomeGeneration] {
        generations.sorted { (Int($0.gen) ?? 0) > (Int($1.gen) ?? 0) }
    }
}
