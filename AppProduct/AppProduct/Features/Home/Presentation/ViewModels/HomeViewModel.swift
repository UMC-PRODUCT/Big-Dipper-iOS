//
//  HomeViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 1/19/26.
//

import Foundation

/// 홈 화면의 전반적인 상태와 비즈니스 로직을 관리하는 뷰 모델입니다.
///
/// 기수 정보, 패널티 현황, 일정 데이터, 최근 공지사항 등을 관리하며
/// 뷰의 상태 변화를 트리거합니다.
@Observable
final class HomeViewModel {

    // MARK: - Property

    private let container: DIContainer
    private var useCaseProvider: HomeUseCaseProviding {
        container.resolve(HomeUseCaseProviding.self)
    }
    private var genRepository: ChallengerGenRepositoryProtocol {
        container.resolve(ChallengerGenRepositoryProtocol.self)
    }

    /// 프로필에서 받은 역할 정보 (공지 API 호출 시 사용)
    private(set) var roles: [ChallengerRole] = []

    /// 기수 정보 데이터 (로딩 상태 포함)
    private(set) var seasonData: Loadable<[SeasonType]> = .idle

    /// 기수별 패널티 정보 데이터 (로딩 상태 포함)
    private(set) var generationData: Loadable<[GenerationData]> = .idle

    /// 날짜별 일정 데이터 딕셔너리
    /// - Key: KST 자정 기준 날짜
    /// - Value: 해당 날짜의 일정 리스트 ([ScheduleDetailData])
    var scheduleByDates: [Date: [ScheduleDetailData]] = [:]

    /// 최근 공지사항 데이터 (로딩 상태 포함)
    private(set) var recentNoticeData: Loadable<[RecentNoticeData]> = .idle

    /// 홈 초기 데이터를 한 번이라도 로드했는지 여부
    private var hasFetchedInitialData: Bool = false

    /// 일정이 등록된 날짜들의 집합
    var scheduleDates: Set<Date> {
        Set(scheduleByDates.keys)
    }

    // MARK: - Init

    init(container: DIContainer) {
        self.container = container
    }

    // MARK: - Function

    /// 홈 화면 진입 시 전체 데이터 로드
    ///
    /// 프로필 조회 후 역할 정보를 기반으로 일정, 공지를 병렬 조회합니다.
    @MainActor
    func fetchAll() async {
        await fetchProfile()

        async let scheduleTask: () = fetchSchedules()
        async let noticeTask: () = fetchRecentNotices()
        _ = await (scheduleTask, noticeTask)
        hasFetchedInitialData = true
    }

    /// 홈 초기 데이터를 아직 로드하지 않은 경우에만 조회합니다.
    @MainActor
    func fetchAllIfNeeded() async {
        guard !hasFetchedInitialData else { return }
        await fetchAll()
    }

    /// 프로필 조회 (기수 카드 + 역할 정보 + AppStorage 저장)
    @MainActor
    func fetchProfile() async {
        seasonData = .loading
        generationData = .loading
        do {
            let result = try await useCaseProvider
                .fetchMyProfileUseCase.execute()
            roles = result.roles
            seasonData = .loaded(result.seasonTypes)
            saveProfileToStorage(result)
            syncGenerationMappings(result.generations)
            applyGenerationsFromProfile(result.generations)
        } catch let error as AppError {
            seasonData = .failed(error)
            generationData = .failed(error)
        } catch {
            let appError = AppError.unknown(message: error.localizedDescription)
            seasonData = .failed(appError)
            generationData = .failed(appError)
        }
    }

    // MARK: - Private Function

    /// 프로필 정보를 AppStorage(UserDefaults)에 저장
    ///
    /// 최신 기수 정보는 유지하되, 대표 역할은 최고 권한 기준으로 저장합니다.
    /// 다른 Feature에서 `@AppStorage(AppStorageKey.xxx)`로 즉시 접근 가능합니다.
    private func saveProfileToStorage(_ result: HomeProfileResult) {
        let defaults = UserDefaults.standard
        let latestRole = result.roles.latestHighestPriorityRole
        let resolvedRole = ManagementTeam.highestPriority(
            in: result.roles.map(\.roleType)
        ) ?? latestRole?.roleType ?? .challenger
        let isApproved = isApprovedProfile(result)

        defaults.set(result.memberId, forKey: AppStorageKey.memberId)
        defaults.set(result.schoolId, forKey: AppStorageKey.schoolId)
        defaults.set(result.schoolName, forKey: AppStorageKey.schoolName)
        defaults.set(result.latestGisuId ?? 0, forKey: AppStorageKey.gisuId)
        defaults.set(result.latestChallengerId ?? 0, forKey: AppStorageKey.challengerId)
        defaults.set(result.chapterId ?? 0, forKey: AppStorageKey.chapterId)
        defaults.set(result.chapterName, forKey: AppStorageKey.chapterName)
        defaults.set(result.part?.apiValue ?? "", forKey: AppStorageKey.responsiblePart)
        defaults.set(
            latestRole?.organizationType.rawValue ?? OrganizationType.chapter.rawValue,
            forKey: AppStorageKey.organizationType
        )
        defaults.set(
            latestRole?.organizationId ?? (result.chapterId ?? 0),
            forKey: AppStorageKey.organizationId
        )
        defaults.set(resolvedRole.rawValue, forKey: AppStorageKey.memberRole)
        defaults.set(
            result.roles.map(\.roleType.rawValue),
            forKey: AppStorageKey.memberRoles
        )
        defaults.set(
            encodeGenerationOrganizations(result.generationOrganizations),
            forKey: AppStorageKey.generationOrganizations
        )
        defaults.set(isApproved, forKey: AppStorageKey.canAutoLogin)
        container.resolve(UserSessionManager.self).updateRole(
            resolvedRole,
            allRoles: result.roles.map(\.roleType)
        )
        NotificationCenter.default.post(name: .memberProfileUpdated, object: nil)
    }

    private func encodeGenerationOrganizations(_ contexts: [GenerationOrganizationContext]) -> String {
        guard let data = try? JSONEncoder().encode(contexts),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func isApprovedProfile(_ result: HomeProfileResult) -> Bool {
        if !result.generations.isEmpty {
            return true
        }

        for seasonType in result.seasonTypes {
            if case .gens(let generations) = seasonType, !generations.isEmpty {
                return true
            }
        }

        return false
    }

    /// 프로필 응답의 기수 데이터를 홈 화면 상태로 반영합니다.
    @MainActor
    private func applyGenerationsFromProfile(_ generations: [GenerationData]) {
        generationData = .loading
        generationData = .loaded(generations.sorted { $0.gen > $1.gen })
    }

    /// 챌린저 이력 기반 (gen, gisuId) 매핑을 SwiftData(CloudKit)에 동기화합니다.
    @MainActor
    private func syncGenerationMappings(_ generations: [GenerationData]) {
        let pairs = generations.map { (gen: $0.gen, gisuId: $0.gisuId) }
        do {
            try genRepository.replaceMappings(pairs)
            NotificationCenter.default.post(name: .generationMappingsUpdated, object: nil)
        } catch {
            // 매핑 저장 실패는 홈 화면 표시에 치명적이지 않으므로 상태를 깨지 않습니다.
            print("[Home] failed to sync generation mappings: \(error)")
        }
    }

    /// 월별 일정 조회 (V2 `from`/`to` 변환)
    ///
    /// 화면이 보고 있는 (year, month) 를 KST 기준 월초/월말 Date 로 변환해
    /// V2 일정 목록 API 를 호출합니다. 캘린더 화면 특성상 출석 필수 여부와 무관한
    /// 모든 일정을 보여줘야 하므로 `isAttendanceRequired = false` 로 고정 호출합니다.
    ///
    /// - Parameters:
    ///   - year: 조회 연도 (nil이면 현재 연도, KST 기준)
    ///   - month: 조회 월 (nil이면 현재 월, KST 기준)
    @MainActor
    func fetchSchedules(year: Int? = nil, month: Int? = nil) async {
        let calendar = Calendar.kstGregorian
        let now = Date()
        let y = year ?? calendar.component(.year, from: now)
        let m = month ?? calendar.component(.month, from: now)

        guard
            let startOfMonth = calendar.date(from: DateComponents(year: y, month: m, day: 1)),
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
        else {
            scheduleByDates = [:]
            return
        }

        let from = startOfMonth.kstStartOfDay
        let to = endOfMonth.kstEndOfDay

        do {
            scheduleByDates = try await useCaseProvider
                .fetchSchedulesUseCase.execute(
                    from: from,
                    to: to,
                    isAttendanceRequired: false
                )
        } catch {
            scheduleByDates = [:]
        }
    }

    /// 최근 공지 조회 (최신 기수 기준)
    @MainActor
    func fetchRecentNotices() async {
        let latestRoleGisuId = roles.max(by: { $0.gisu < $1.gisu })?.gisuId
        let fallbackGisuId = UserDefaults.standard.integer(
            forKey: AppStorageKey.gisuId
        )
        let gisuId = latestRoleGisuId ?? fallbackGisuId

        guard gisuId > 0 else {
            recentNoticeData = .loaded([])
            return
        }

        recentNoticeData = .loading
        do {
            let query = NoticeListRequestDTO(
                gisuId: gisuId,
                size: 5
            )
            let result = try await useCaseProvider
                .fetchRecentNoticesUseCase.execute(query: query)
            recentNoticeData = .loaded(result)
        } catch let error as AppError {
            recentNoticeData = .failed(error)
        } catch {
            recentNoticeData = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }

    /// 특정 날짜에 해당하는 일정 목록을 반환합니다.
    ///
    /// - Parameter date: 조회하려는 날짜
    /// - Returns: 해당 날짜의 일정 데이터 배열 (없으면 빈 배열 반환)
    func getSchedules(_ date: Date) -> [ScheduleDetailData] {
        let normalizedDate = Calendar.kstGregorian.startOfDay(for: date)
        return scheduleByDates[normalizedDate] ?? []
    }

}

extension Array where Element == ChallengerRole {
    var latestHighestPriorityRole: ChallengerRole? {
        guard let latestGisu = map(\.gisu).max() else {
            return nil
        }

        return filter { $0.gisu == latestGisu }
            .max { lhs, rhs in
                lhs.roleType < rhs.roleType
            }
    }
}

extension HomeViewModel {
    static func emptyPreview(container: DIContainer) -> HomeViewModel {
        let viewModel = HomeViewModel(container: container)
        viewModel.roles = []
        viewModel.seasonData = .loaded([
            .days(0),
            .gens([])
        ])
        viewModel.generationData = .loaded([])
        viewModel.scheduleByDates = [:]
        viewModel.recentNoticeData = .loaded([])
        return viewModel
    }

    static func zeroPenaltyPreview(container: DIContainer) -> HomeViewModel {
        let viewModel = HomeViewModel(container: container)
        viewModel.roles = [
            ChallengerRole(
                challengerId: 1,
                gisu: 6,
                gisuId: 1,
                roleType: .challenger,
                responsiblePart: .front(type: .ios),
                organizationType: .chapter,
                organizationId: 1
            )
        ]
        viewModel.seasonData = .loaded([
            .days(12),
            .gens([6])
        ])
        viewModel.generationData = .loaded([
            GenerationData(
                gisuId: 1,
                gen: 6,
                penaltyPoint: 0,
                rewardPoint: 0,
                pointLogs: [],
                penaltyLogs: []
            )
        ])
        viewModel.scheduleByDates = [:]
        viewModel.recentNoticeData = .loaded([])
        return viewModel
    }
}
