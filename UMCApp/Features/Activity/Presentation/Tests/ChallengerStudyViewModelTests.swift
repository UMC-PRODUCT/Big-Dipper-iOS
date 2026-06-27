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
    useCase: MockFetchCurriculumUseCase
) -> ChallengerStudyViewModel {
    ChallengerStudyViewModel(fetchCurriculumUseCase: useCase)
}

// MARK: - Mocks

/// 결정론적 메시지를 갖는 비분류 에러 — `.unknown` 폴백 매핑 검증용.
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
}

#endif
