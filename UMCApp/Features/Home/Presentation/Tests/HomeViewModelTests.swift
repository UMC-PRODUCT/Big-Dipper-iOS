import CoreDI
import Foundation
import HomeDomain
import NoticeDomain
import Testing
import UMCFoundation
@testable import HomePresentation

@MainActor
@Suite("HomeViewModel — 프로필 로딩 상태 전이")
struct HomeViewModelTests {

    @Test("초기 상태는 .idle")
    func initialStateIsIdle() {
        let viewModel = makeViewModel()

        #expect(viewModel.seasonState == .idle)
        #expect(viewModel.generationState == .idle)
    }

    @Test("성공 → 시즌/세대 모두 .loaded, 세대는 기수 내림차순 정렬")
    func successSetsLoadedWithGenerationsSortedDescending() async {
        let useCase = MockFetchHomeProfileUseCase()
        let profile = makeProfile(generationNumbers: ["11", "13", "12"])
        useCase.result = .success(profile)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchProfile()

        #expect(viewModel.seasonState == .loaded(profile.seasonTypes))
        #expect(viewModel.generationState.value?.map(\.gen) == ["13", "12", "11"])
    }

    @Test("RepositoryError → 두 섹션 모두 .failed(.repository)")
    func repositoryErrorSetsFailed() async {
        let useCase = MockFetchHomeProfileUseCase()
        useCase.result = .failure(RepositoryError.decodingError(detail: "boom"))
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchProfile()

        #expect(viewModel.seasonState == .failed(.repository(.decodingError(detail: "boom"))))
        #expect(viewModel.generationState == .failed(.repository(.decodingError(detail: "boom"))))
    }

    @Test("알 수 없는 에러 → 두 섹션 모두 .failed(.unknown)")
    func unknownErrorSetsFailed() async {
        let useCase = MockFetchHomeProfileUseCase()
        useCase.result = .failure(DummyError())
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchProfile()

        #expect(viewModel.seasonState.error != nil)
        #expect(viewModel.generationState.error != nil)
    }

    @Test("취소(CancellationError) → 이전 상태로 복원")
    func cancellationRestoresPreviousState() async {
        let useCase = MockFetchHomeProfileUseCase()
        let profile = makeProfile(generationNumbers: ["11"])
        useCase.result = .success(profile)
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchProfile()
        let loadedSeasonState = viewModel.seasonState
        let loadedGenerationState = viewModel.generationState

        useCase.result = .failure(CancellationError())
        await viewModel.fetchProfile()

        #expect(viewModel.seasonState == loadedSeasonState)
        #expect(viewModel.generationState == loadedGenerationState)
    }

    @Test("fetchProfileIfNeeded()는 idle일 때만 로드한다")
    func fetchIfNeededLoadsOnlyWhenIdle() async {
        let useCase = MockFetchHomeProfileUseCase()
        useCase.result = .success(makeProfile(generationNumbers: ["11"]))
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchProfileIfNeeded()
        await viewModel.fetchProfileIfNeeded()

        #expect(useCase.callCount == 1)
    }

    @Test("로딩 중 중복 호출은 무시 (UseCase 1회만 호출)")
    func duplicateCallWhileLoadingIsIgnored() async {
        let useCase = MockFetchHomeProfileUseCase()
        useCase.delayNanoseconds = 50_000_000
        useCase.result = .success(makeProfile(generationNumbers: ["11"]))
        let viewModel = makeViewModel(useCase: useCase)

        let first = Task { await viewModel.fetchProfile() }
        await Task.yield()

        await viewModel.fetchProfile()
        await first.value

        #expect(useCase.callCount == 1)
    }

    @Test("분류 전에는 category(for:)가 .general을 반환한다")
    func categoryDefaultsToGeneralBeforeClassification() {
        let viewModel = makeViewModel()

        #expect(viewModel.category(for: "unknown-schedule") == .general)
    }

    @Test("fetchSchedules() 성공 시 일정 제목을 분류해 scheduleCategories를 채운다")
    func fetchSchedulesClassifiesLoadedSchedules() async {
        let schedule = ScheduleDetailData(
            scheduleId: "1",
            name: "알고리즘 스터디",
            description: "",
            tags: [],
            startsAt: .now,
            endsAt: .now.addingTimeInterval(3600),
            isParticipant: true
        )
        let fetchSchedulesUseCase = MockFetchSchedulesUseCase(result: [.now: [schedule]])
        let classifyScheduleUseCase = MockClassifyScheduleUseCase()
        classifyScheduleUseCase.resultsByTitle["알고리즘 스터디"] = .study
        let viewModel = makeViewModel(
            fetchSchedulesUseCase: fetchSchedulesUseCase,
            classifyScheduleUseCase: classifyScheduleUseCase
        )

        await viewModel.fetchSchedules()

        #expect(viewModel.category(for: "1") == .study)
        #expect(classifyScheduleUseCase.classifiedTitles == ["알고리즘 스터디"])
    }
}

// MARK: - Helpers

private struct DummyError: Error {}

@MainActor
private func makeViewModel(
    useCase: FetchHomeProfileUseCaseProtocol? = nil,
    recentNoticesUseCase: FetchRecentNoticesUseCaseProtocol? = nil,
    fetchSchedulesUseCase: FetchSchedulesUseCaseProtocol? = nil,
    classifyScheduleUseCase: ClassifyScheduleUseCaseProtocol? = nil
) -> HomeViewModel {
    let useCase = useCase ?? MockFetchHomeProfileUseCase()
    let recentNoticesUseCase = recentNoticesUseCase ?? MockFetchRecentNoticesUseCase()
    let fetchSchedulesUseCase = fetchSchedulesUseCase ?? MockFetchSchedulesUseCase()
    let classifyScheduleUseCase = classifyScheduleUseCase ?? MockClassifyScheduleUseCase()
    let container = DIContainer()
    container.register(FetchHomeProfileUseCaseProtocol.self) { useCase }
    container.register(FetchRecentNoticesUseCaseProtocol.self) { recentNoticesUseCase }
    container.register(FetchSchedulesUseCaseProtocol.self) { fetchSchedulesUseCase }
    container.register(ClassifyScheduleUseCaseProtocol.self) { classifyScheduleUseCase }
    return HomeViewModel(container: container)
}

private func makeProfile(generationNumbers: [String]) -> HomeProfileResult {
    HomeProfileResult(
        memberId: "1",
        seasonTypes: [.gens(generationNumbers), .days(100)],
        generations: generationNumbers.map {
            HomeGeneration(gisuId: "id-\($0)", gen: $0, penaltyPoint: 0, rewardPoint: 0, pointLogs: [])
        }
    )
}

// MARK: - Mocks

private final class MockFetchHomeProfileUseCase: FetchHomeProfileUseCaseProtocol, @unchecked Sendable {

    enum MockError: Error, Equatable {
        case notStubbed
    }

    var result: Result<HomeProfileResult, Error> = .failure(MockError.notStubbed)
    /// 로딩 중 중복 호출 방지 검증용 인위적 지연 (기본값: 지연 없음)
    var delayNanoseconds: UInt64 = 0
    private(set) var callCount = 0

    func execute() async throws -> HomeProfileResult {
        callCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try result.get()
    }
}

private final class MockFetchRecentNoticesUseCase: FetchRecentNoticesUseCaseProtocol, @unchecked Sendable {
    var result: Result<[NoticeItemModel], Error> = .success([])

    func execute(gisuId: String) async throws -> [NoticeItemModel] {
        try result.get()
    }
}

/// 프로필 로딩 상태 전이 테스트는 일정 조회 결과와 무관하므로 빈 결과만 반환한다.
private struct MockFetchSchedulesUseCase: FetchSchedulesUseCaseProtocol, Sendable {
    var result: [Date: [ScheduleDetailData]] = [:]

    func execute(from: Date, to: Date, isAttendanceRequired: Bool) async throws -> [Date: [ScheduleDetailData]] {
        result
    }
}

/// 제목별로 분류 결과를 주입할 수 있는 Mock. 매칭이 없으면 `.general`을 반환한다.
private final class MockClassifyScheduleUseCase: ClassifyScheduleUseCaseProtocol, @unchecked Sendable {
    var resultsByTitle: [String: ScheduleIconCategory] = [:]
    private(set) var classifiedTitles: [String] = []

    func execute(title: String) async -> ScheduleIconCategory {
        classifiedTitles.append(title)
        return resultsByTitle[title] ?? .general
    }
}
