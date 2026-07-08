import Testing
@testable import AuthDomain

// MARK: - Mocks

#if DEBUG

/// `AuthRepositoryProtocol`의 전체 계약을 컨트롤하는 Mock.
private final class MockAuthRepository: @unchecked Sendable, AuthRepositoryProtocol {

    enum MockError: Error {
        /// 에러 전파 경로 검증용 — Repository가 의도적으로 실패할 때 던지는 스텁 에러
        case stubbed
    }

    // MARK: 입출력 기록

    var hasSessionResult: Bool = false
    private(set) var hasSessionCallCount: Int = 0

    var refreshSessionError: Error?
    private(set) var refreshSessionCallCount: Int = 0

    var fetchMyProfileResult: Profile = Profile(
        memberId: "0",
        name: "",
        nickname: "",
        generations: []
    )
    var fetchMyProfileError: Error?
    private(set) var fetchMyProfileCallCount: Int = 0

    // MARK: AuthRepositoryProtocol

    func hasSession() async -> Bool {
        hasSessionCallCount += 1
        return hasSessionResult
    }

    func refreshSession() async throws {
        refreshSessionCallCount += 1
        if let refreshSessionError {
            throw refreshSessionError
        }
    }

    func fetchMyProfile() async throws -> Profile {
        fetchMyProfileCallCount += 1
        if let fetchMyProfileError {
            throw fetchMyProfileError
        }
        return fetchMyProfileResult
    }
}

#endif

// MARK: - Helpers

private func makeUseCase(repository: MockAuthRepository) -> CheckAuthStatusUseCase {
    CheckAuthStatusUseCase(
        repository: repository,
        fetchMyProfileUseCase: FetchMyProfileUseCase(repository: repository)
    )
}

// MARK: - Tests

@Suite("CheckAuthStatusUseCase — 부트스트랩 인증 상태 판정")
struct CheckAuthStatusUseCaseTests {

    @Test("토큰이 없으면 세션 갱신·프로필 조회 없이 notLoggedIn")
    func returnsNotLoggedInWhenNoSession() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = false
        let useCase = makeUseCase(repository: repository)

        let status = await useCase.execute()

        #expect(status == .notLoggedIn)
        #expect(repository.refreshSessionCallCount == 0)
        #expect(repository.fetchMyProfileCallCount == 0)
    }

    @Test("세션 갱신이 실패해도 기존 토큰으로 프로필 조회를 시도해 승인 판정")
    func fallsBackToProfileFetchWhenRefreshFails() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        repository.refreshSessionError = MockAuthRepository.MockError.stubbed
        repository.fetchMyProfileResult = Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: ["11"]
        )
        let useCase = makeUseCase(repository: repository)

        let status = await useCase.execute()

        #expect(status == .approved)
        #expect(repository.refreshSessionCallCount == 1)
        #expect(repository.fetchMyProfileCallCount == 1)
    }

    @Test("프로필에 소속 기수가 있으면 approved")
    func returnsApprovedWhenProfileHasGenerations() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        repository.fetchMyProfileResult = Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: ["10", "11"]
        )
        let useCase = makeUseCase(repository: repository)

        let status = await useCase.execute()

        #expect(status == .approved)
    }

    @Test("프로필 조회는 성공했지만 소속 기수가 없으면 pendingApproval")
    func returnsPendingApprovalWhenProfileHasNoGenerations() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        repository.fetchMyProfileResult = Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: []
        )
        let useCase = makeUseCase(repository: repository)

        let status = await useCase.execute()

        #expect(status == .pendingApproval)
    }

    @Test("프로필 조회 자체가 실패하면 notLoggedIn")
    func returnsNotLoggedInWhenProfileFetchFails() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        repository.fetchMyProfileError = MockAuthRepository.MockError.stubbed
        let useCase = makeUseCase(repository: repository)

        let status = await useCase.execute()

        #expect(status == .notLoggedIn)
    }
}
