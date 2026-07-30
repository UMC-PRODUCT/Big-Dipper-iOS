//
//  ChallengerStudyViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation
import Testing
import ActivityDomain
import UMCFoundation
@testable import ActivityPresentation

// 이 테스트 파일은 전부 #if DEBUG 전용 Mock 에 의존하므로 본문 전체를 가드한다.
#if DEBUG

// MARK: - Helpers

private func makeProgress(
    partName: String = "iOS",
    curriculumTitle: String = "1주차 OT",
    completedCount: Int = 2,
    totalCount: Int = 8
) -> CurriculumProgressModel {
    CurriculumProgressModel(
        partName: partName,
        curriculumTitle: curriculumTitle,
        completedCount: completedCount,
        totalCount: totalCount
    )
}

/// 검증 대상은 `week`/`status` 뿐이며, `platform`/`title`/`missionTitle` 은
/// 상태 검증과 무관한 고정 filler 값이다.
private func makeMission(
    week: Int = 1,
    status: MissionStatus = .inProgress
) -> MissionCardModel {
    MissionCardModel(
        week: week,
        platform: "iOS",
        title: "\(week)주차 OT",
        missionTitle: "링크를 제출하세요",
        status: status
    )
}

private func makeOverview(
    progress: CurriculumProgressModel = makeProgress(),
    missions: [MissionCardModel] = [makeMission()]
) -> CurriculumOverview {
    CurriculumOverview(progress: progress, missions: missions)
}

@MainActor
private func makeViewModel(
    useCase: any FetchCurriculumOverviewUseCaseProtocol = MockFetchCurriculumOverviewUseCase()
) -> ChallengerStudyViewModel {
    ChallengerStudyViewModel(fetchCurriculumOverviewUseCase: useCase)
}

// MARK: - Mocks

/// `.unknown` 폴백 매핑 검증용 비분류 에러. 결정론적 메시지를 갖는다.
private enum TestError: Error, LocalizedError {
    case unclassified
    var errorDescription: String? { "테스트 알 수 없는 오류" }
}

private final class MockFetchCurriculumOverviewUseCase: @unchecked Sendable,
    FetchCurriculumOverviewUseCaseProtocol {

    var result: Result<CurriculumOverview, Error> = .success(makeOverview())
    private(set) var executeCallCount = 0

    func execute() async throws -> CurriculumOverview {
        executeCallCount += 1
        return try result.get()
    }
}

/// 재진입 가드 검증용. `execute()` 가 지정 시간만큼 suspend 해 로딩 상태를 유지한다.
private final class SlowMockFetchCurriculumOverviewUseCase: @unchecked Sendable,
    FetchCurriculumOverviewUseCaseProtocol {

    private let overview: CurriculumOverview
    private let delayNanoseconds: UInt64
    private(set) var executeCallCount = 0

    init(overview: CurriculumOverview, delayNanoseconds: UInt64) {
        self.overview = overview
        self.delayNanoseconds = delayNanoseconds
    }

    func execute() async throws -> CurriculumOverview {
        executeCallCount += 1
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        return overview
    }
}

// MARK: - 에러 매핑 케이스

/// UseCase 가 던진 에러 타입별 → ViewModel 이 매핑해야 할 `AppError` 짝.
///
/// 형제 catch 분기(AppError 패스스루 / Domain / Network / Repository / unknown)를
/// 빠짐없이 대칭 검증하기 위한 파라미터 집합입니다.
private enum ErrorMappingCase: CaseIterable {
    case appErrorPassthrough
    case domain
    case network
    case repository
    case unknownFallback

    var thrown: Error {
        switch self {
        case .appErrorPassthrough:
            return AppError.repository(.decodingError(detail: "이미 래핑됨"))
        case .domain:
            return DomainError.curriculumUnavailableForGeneration
        case .network:
            return NetworkError.unauthorized
        case .repository:
            return RepositoryError.serverError(code: "STUDY-500", message: "서버 오류")
        case .unknownFallback:
            return TestError.unclassified
        }
    }

    /// 매핑 후 기대되는 `AppError`. 패스스루는 final catch 폴백(`.unknown`)과 결과가
    /// 달라 조기 `catch as AppError` 분기가 실제로 동작했음을 구분한다.
    var expected: AppError {
        switch self {
        case .appErrorPassthrough:
            return .repository(.decodingError(detail: "이미 래핑됨"))
        case .domain:
            return .domain(.curriculumUnavailableForGeneration)
        case .network:
            return .network(.unauthorized)
        case .repository:
            return .repository(.serverError(code: "STUDY-500", message: "서버 오류"))
        case .unknownFallback:
            return .unknown(message: "테스트 알 수 없는 오류")
        }
    }
}

// MARK: - 취소 에러 케이스

/// `.failed` 가 아니라 이전 상태로 복원돼야 하는 두 취소 경로.
///
/// `CancellationError` / `NSURLErrorCancelled` 분기를 대칭 검증한다.
private enum CancellationCase: CaseIterable {
    case swiftCancellation
    case urlCancellation

    var thrown: Error {
        switch self {
        case .swiftCancellation:
            return CancellationError()
        case .urlCancellation:
            return NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil)
        }
    }
}

// MARK: - 커리큘럼 개요 조회

// Suite 전체 @MainActor — SUT(ChallengerStudyViewModel)가 @MainActor 격리이므로 필요.
@MainActor
@Suite("ChallengerStudyViewModel — 커리큘럼 개요 조회 (도메인 규칙)")
struct ChallengerStudyViewModelTests {

    @Test("정상 — 단일 조회 결과가 진행률·미션 두 상태에 함께 .loaded 로 담긴다")
    func loadFillsBothStatesFromSingleFetch() async {
        let expectedProgress = makeProgress(
            partName: "Spring",
            curriculumTitle: "3주차 세션",
            completedCount: 5,
            totalCount: 10
        )
        let expectedMissions = [makeMission(week: 1, status: .pass), makeMission(week: 2)]
        let useCase = MockFetchCurriculumOverviewUseCase()
        useCase.result = .success(
            makeOverview(progress: expectedProgress, missions: expectedMissions)
        )
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.load()

        #expect(viewModel.curriculumState == .loaded(expectedProgress))
        #expect(viewModel.missionsState == .loaded(expectedMissions))
    }

    /// 진행률과 미션을 각각 조회하던 구조에서는 화면 1회 로드에 동일 엔드포인트가 2회
    /// 호출됐다. 단일 조회로 통합된 구조가 회귀하지 않도록 호출 횟수를 박제한다.
    @Test("load() 1회는 UseCase 를 1회만 호출한다 (중복 조회 회귀 방지)")
    func loadQueriesUseCaseOnlyOnce() async {
        let useCase = MockFetchCurriculumOverviewUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.load()

        #expect(useCase.executeCallCount == 1)
    }

    // 파라미터 타입 `ErrorMappingCase` 가 file-private 이라 메서드도 fileprivate 로 맞춘다.
    @Test(
        "에러 타입별 → 대응 AppError 로 매핑돼 두 상태가 함께 .failed 로 전이",
        arguments: ErrorMappingCase.allCases
    )
    fileprivate func loadMapsErrorToFailedOnBothStates(errorCase: ErrorMappingCase) async {
        let useCase = MockFetchCurriculumOverviewUseCase()
        useCase.result = .failure(errorCase.thrown)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.load()

        // 단일 조회이므로 한쪽만 실패하는 상황은 성립하지 않는다. 두 상태가 같은 에러로
        // 함께 전이돼야 화면이 한쪽만 에러 카드를 띄우는 어긋남이 생기지 않는다.
        #expect(viewModel.curriculumState == .failed(errorCase.expected))
        #expect(viewModel.missionsState == .failed(errorCase.expected))
    }

    // 파라미터 타입 `CancellationCase` 가 file-private 이라 메서드도 fileprivate 로 맞춘다.
    @Test(
        "취소 에러 발생 시 두 상태 모두 이전 상태로 롤백 (허위 .failed(.unknown) 방지)",
        arguments: CancellationCase.allCases
    )
    fileprivate func cancellationRollsBackBothStates(
        cancellationCase: CancellationCase
    ) async {
        let previousProgress = makeProgress(curriculumTitle: "이전 주차")
        let previousMissions = [makeMission(week: 9, status: .locked)]
        let useCase = MockFetchCurriculumOverviewUseCase()
        useCase.result = .success(
            makeOverview(progress: previousProgress, missions: previousMissions)
        )
        let viewModel = makeViewModel(useCase: useCase)

        // 1차 로드로 직전 상태를 .loaded 로 만든다.
        await viewModel.load()
        #expect(viewModel.curriculumState == .loaded(previousProgress))
        #expect(viewModel.missionsState == .loaded(previousMissions))

        // 2차 요청이 취소되면 .failed 가 아니라 직전 .loaded 로 복원돼야 한다.
        useCase.result = .failure(cancellationCase.thrown)
        await viewModel.load()

        #expect(viewModel.curriculumState == .loaded(previousProgress))
        #expect(viewModel.missionsState == .loaded(previousMissions))
    }

    @Test("로딩 중 중복 호출은 무시 (execute 1회만 호출 — 취소 롤백 stuck-loading 방지)")
    func duplicateLoadWhileLoadingIsIgnored() async {
        let expected = makeOverview()
        let useCase = SlowMockFetchCurriculumOverviewUseCase(
            overview: expected,
            delayNanoseconds: 100_000_000  // 0.1s 지연으로 로딩 상태 유지
        )
        let viewModel = makeViewModel(useCase: useCase)

        let first = Task { await viewModel.load() }
        // 첫 호출이 .loading 을 세팅할 때까지 양보한다.
        await Task.yield()

        // 로딩 중 2차 호출은 재진입 가드로 즉시 return 된다.
        await viewModel.load()
        await first.value

        #expect(useCase.executeCallCount == 1)
        #expect(viewModel.curriculumState == .loaded(expected.progress))
        #expect(viewModel.missionsState == .loaded(expected.missions))
    }

    @Test("조회 중에는 isLoading 이 true 로 노출된다 (재시도 버튼 로딩 피드백)")
    func isLoadingReflectsInFlightFetch() async {
        let useCase = SlowMockFetchCurriculumOverviewUseCase(
            overview: makeOverview(),
            delayNanoseconds: 100_000_000
        )
        let viewModel = makeViewModel(useCase: useCase)
        #expect(viewModel.isLoading == false)

        let loading = Task { await viewModel.load() }
        await Task.yield()
        #expect(viewModel.isLoading)

        await loading.value
        #expect(viewModel.isLoading == false)
    }
}

#endif
