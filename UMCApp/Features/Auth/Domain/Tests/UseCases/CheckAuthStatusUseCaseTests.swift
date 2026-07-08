import Testing
@testable import AuthDomain

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
        repository.refreshSessionError = AuthTestError.boom
        repository.fetchMyProfileResult = .success(Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: ["11"]
        ))
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
        repository.fetchMyProfileResult = .success(Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: ["10", "11"]
        ))
        let useCase = makeUseCase(repository: repository)

        let status = await useCase.execute()

        #expect(status == .approved)
        #expect(repository.refreshSessionCallCount == 1)
        #expect(repository.fetchMyProfileCallCount == 1)
    }

    @Test("프로필 조회는 성공했지만 소속 기수가 없으면 pendingApproval")
    func returnsPendingApprovalWhenProfileHasNoGenerations() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        repository.fetchMyProfileResult = .success(Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: []
        ))
        let useCase = makeUseCase(repository: repository)

        let status = await useCase.execute()

        #expect(status == .pendingApproval)
        #expect(repository.refreshSessionCallCount == 1)
        #expect(repository.fetchMyProfileCallCount == 1)
    }

    @Test("프로필 조회 자체가 실패하면 notLoggedIn")
    func returnsNotLoggedInWhenProfileFetchFails() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        repository.fetchMyProfileResult = .failure(AuthTestError.boom)
        let useCase = makeUseCase(repository: repository)

        let status = await useCase.execute()

        #expect(status == .notLoggedIn)
        #expect(repository.refreshSessionCallCount == 1)
        #expect(repository.fetchMyProfileCallCount == 1)
    }
}
