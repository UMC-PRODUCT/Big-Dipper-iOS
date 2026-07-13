//
//  HomeViewModel.swift
//  HomePresentation
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDI
import Foundation
import HomeDomain
import NoticeDomain
import UMCFoundation

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

    /// 일정이 있는 날짜 집합 (캘린더 그리드의 점 표시용).
    public var scheduleDates: Set<Date> {
        Set(scheduleByDates.keys)
    }

    private let fetchMyProfileUseCase: FetchHomeProfileUseCaseProtocol
    private let fetchRecentNoticesUseCase: FetchRecentNoticesUseCaseProtocol
    private let fetchMySchedulesUseCase: FetchSchedulesUseCaseProtocol

    // MARK: - Init

    public init(container: DIContainer) {
        fetchMyProfileUseCase = container.resolve(FetchHomeProfileUseCaseProtocol.self)
        fetchRecentNoticesUseCase = container.resolve(FetchRecentNoticesUseCaseProtocol.self)
        fetchMySchedulesUseCase = container.resolve(FetchSchedulesUseCaseProtocol.self)
    }

    // MARK: - Function

    /// 아직 로딩을 시작하지 않았을 때만 프로필을 조회한다. `.task`의 최초 트리거로 사용한다.
    public func fetchProfileIfNeeded() async {
        guard seasonState.isIdle else { return }
        await fetchProfile()
    }

    /// 내 프로필을 조회해 시즌/세대 카드 상태를 갱신한다. 실패 시 인라인 `.failed` 상태로 표시한다.
    /// 세대 조회가 성공하면 최신 기수를 기준으로 최근 공지도 함께 조회한다.
    public func fetchProfile() async {
        if seasonState.isLoading { return }

        let previousSeasonState = seasonState
        let previousGenerationState = generationState
        seasonState = .loading
        generationState = .loading

        do {
            let profile = try await fetchMyProfileUseCase.execute()
            let sortedGenerations = sortedByGenerationDescending(profile.generations)
            seasonState = .loaded(profile.seasonTypes)
            generationState = .loaded(sortedGenerations)
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

        guard
            let startOfMonth = calendar.date(from: DateComponents(year: targetYear, month: targetMonth, day: 1)),
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
        else {
            scheduleByDates = [:]
            return
        }

        do {
            scheduleByDates = try await fetchMySchedulesUseCase.execute(
                from: startOfMonth.kstStartOfDay,
                to: endOfMonth.kstEndOfDay,
                isAttendanceRequired: false
            )
        } catch {
            scheduleByDates = [:]
        }
    }

    /// 특정 날짜(KST 자정 기준 정규화)에 해당하는 일정 목록을 반환한다.
    public func getSchedules(_ date: Date) -> [ScheduleDetailData] {
        scheduleByDates[Calendar.kstGregorian.startOfDay(for: date)] ?? []
    }

    // MARK: - Private Function

    /// 최신 기수의 최근 공지 5건을 조회한다. 소속 기수가 없으면 빈 목록으로 처리한다.
    private func fetchRecentNotices(latestGisuId: String?) async {
        guard let gisuId = latestGisuId, !gisuId.isEmpty else {
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
