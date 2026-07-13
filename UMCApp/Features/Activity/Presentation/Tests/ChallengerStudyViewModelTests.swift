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

@MainActor
private func makeViewModel(
    useCase: any FetchCurriculumUseCaseProtocol
) -> ChallengerStudyViewModel {
    ChallengerStudyViewModel(fetchCurriculumUseCase: useCase)
}

// MARK: - Mocks

/// `.unknown` 폴백 매핑 검증용 비분류 에러. 결정론적 메시지를 갖는다.
private enum TestError: Error, LocalizedError {
    case unclassified
    var errorDescription: String? { "테스트 알 수 없는 오류" }
}

private final class MockFetchCurriculumUseCase: @unchecked Sendable,
    FetchCurriculumUseCaseProtocol {

    var result: Result<CurriculumProgressModel, Error> = .success(makeProgress())
    private(set) var executeCallCount = 0

    func execute() async throws -> CurriculumProgressModel {
        executeCallCount += 1
        return try result.get()
    }
}

/// 재진입 가드 검증용. `execute()` 가 지정 시간만큼 suspend 해 로딩 상태를 유지한다.
private final class SlowMockFetchCurriculumUseCase: @unchecked Sendable,
    FetchCurriculumUseCaseProtocol {

    private let progress: CurriculumProgressModel
    private let delayNanoseconds: UInt64
    private(set) var executeCallCount = 0

    init(progress: CurriculumProgressModel, delayNanoseconds: UInt64) {
        self.progress = progress
        self.delayNanoseconds = delayNanoseconds
    }

    func execute() async throws -> CurriculumProgressModel {
        executeCallCount += 1
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        return progress
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

// MARK: - 커리큘럼 조회

// Suite 전체 @MainActor — SUT(ChallengerStudyViewModel)가 @MainActor 격리이므로 필요.
@MainActor
@Suite("ChallengerStudyViewModel — 커리큘럼 조회 (도메인 규칙)")
struct ChallengerStudyViewModelTests {

    @Test("정상 — execute 위임 + .loaded 전이 + 1회 호출")
    func fetchCurriculumLoadsProgress() async {
        let expected = makeProgress(
            partName: "Spring",
            curriculumTitle: "3주차 세션",
            completedCount: 5,
            totalCount: 10
        )
        let useCase = MockFetchCurriculumUseCase()
        useCase.result = .success(expected)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchCurriculum()

        #expect(useCase.executeCallCount == 1)
        #expect(viewModel.curriculumState == .loaded(expected))
    }

    // 파라미터 타입 `ErrorMappingCase` 가 file-private 이라 메서드도 fileprivate 로 맞춘다.
    @Test(
        "에러 타입별 → 대응 AppError 로 매핑된 .failed 전이",
        arguments: ErrorMappingCase.allCases
    )
    fileprivate func fetchCurriculumMapsErrorToFailed(errorCase: ErrorMappingCase) async {
        let useCase = MockFetchCurriculumUseCase()
        useCase.result = .failure(errorCase.thrown)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchCurriculum()

        #expect(viewModel.curriculumState == .failed(errorCase.expected))
    }

    // 파라미터 타입 `CancellationCase` 가 file-private 이라 메서드도 fileprivate 로 맞춘다.
    @Test(
        "취소 에러 발생 시 이전 상태로 롤백 (허위 .failed(.unknown) 노출 방지)",
        arguments: CancellationCase.allCases
    )
    fileprivate func cancellationRollsBackToPreviousState(
        cancellationCase: CancellationCase
    ) async {
        let previous = makeProgress(curriculumTitle: "이전 주차")
        let useCase = MockFetchCurriculumUseCase()
        useCase.result = .success(previous)
        let viewModel = makeViewModel(useCase: useCase)

        // 1차 로드로 직전 상태를 .loaded 로 만든다.
        await viewModel.fetchCurriculum()
        #expect(viewModel.curriculumState == .loaded(previous))

        // 2차 요청이 취소되면 .failed 가 아니라 직전 .loaded 로 복원돼야 한다.
        useCase.result = .failure(cancellationCase.thrown)
        await viewModel.fetchCurriculum()

        #expect(viewModel.curriculumState == .loaded(previous))
    }

    @Test("로딩 중 중복 호출은 무시 (execute 1회만 호출 — 취소 롤백 stuck-loading 방지)")
    func duplicateFetchWhileLoadingIsIgnored() async {
        let expected = makeProgress()
        let useCase = SlowMockFetchCurriculumUseCase(
            progress: expected,
            delayNanoseconds: 100_000_000  // 0.1s 지연으로 로딩 상태 유지
        )
        let viewModel = makeViewModel(useCase: useCase)

        let first = Task { await viewModel.fetchCurriculum() }
        // 첫 호출이 .loading 을 세팅할 때까지 양보한다.
        await Task.yield()

        // 로딩 중 2차 호출은 재진입 가드로 즉시 return 된다.
        await viewModel.fetchCurriculum()
        await first.value

        #expect(useCase.executeCallCount == 1)
        #expect(viewModel.curriculumState == .loaded(expected))
    }
}

#endif
