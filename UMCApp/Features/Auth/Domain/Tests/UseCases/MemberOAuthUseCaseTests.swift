//
//  MemberOAuthUseCaseTests.swift
//  AuthDomainTests
//
//  Created by euijjang97 on 8/10/26.
//

import Testing
@testable import AuthDomain

@Suite("MemberOAuth UseCase — Repository 위임 검증")
struct MemberOAuthUseCaseTests {

    // MARK: - FetchMyOAuthUseCase

    @Test("execute()는 repository.fetchMyOAuth() 결과를 그대로 반환한다")
    func fetchMyOAuthDelegatesToRepository() async throws {
        let repository = MockAuthRepository()
        repository.fetchMyOAuthResult = .success([
            MemberOAuth(memberOAuthId: "1", memberId: "10", provider: .kakao)
        ])
        let useCase = FetchMyOAuthUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(repository.fetchMyOAuthCallCount == 1)
        #expect(result == [MemberOAuth(memberOAuthId: "1", memberId: "10", provider: .kakao)])
    }

    @Test("repository.fetchMyOAuth()가 에러를 던지면 그대로 전파한다")
    func fetchMyOAuthPropagatesError() async {
        let repository = MockAuthRepository()
        repository.fetchMyOAuthResult = .failure(AuthTestError.boom)
        let useCase = FetchMyOAuthUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.execute()
        }
    }

    // MARK: - AddMemberOAuthUseCase

    @Test("execute(oAuthVerificationToken:)는 토큰을 그대로 전달하고 갱신된 목록을 반환한다")
    func addMemberOAuthDelegatesToRepository() async throws {
        let repository = MockAuthRepository()
        repository.addMemberOAuthResult = .success([
            MemberOAuth(memberOAuthId: "1", memberId: "10", provider: .kakao),
            MemberOAuth(memberOAuthId: "2", memberId: "10", provider: .google)
        ])
        let useCase = AddMemberOAuthUseCase(repository: repository)

        let result = try await useCase.execute(oAuthVerificationToken: "verify-token")

        #expect(repository.addMemberOAuthCallCount == 1)
        #expect(repository.addMemberOAuthReceivedToken == "verify-token")
        #expect(result.map(\.provider) == [.kakao, .google])
    }

    @Test("repository.addMemberOAuth()가 에러를 던지면 그대로 전파한다")
    func addMemberOAuthPropagatesError() async {
        let repository = MockAuthRepository()
        repository.addMemberOAuthResult = .failure(AuthTestError.boom)
        let useCase = AddMemberOAuthUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.execute(oAuthVerificationToken: "verify-token")
        }
    }

    // MARK: - DeleteMemberOAuthUseCase

    @Test("execute()는 연동 ID와 소셜별 검증 토큰을 그대로 전달한다")
    func deleteMemberOAuthDelegatesToRepository() async throws {
        let repository = MockAuthRepository()
        let useCase = DeleteMemberOAuthUseCase(repository: repository)

        try await useCase.execute(
            memberOAuthId: "7",
            googleAccessToken: nil,
            kakaoAccessToken: "kakao-token"
        )

        #expect(repository.deleteMemberOAuthCallCount == 1)
        #expect(repository.deleteMemberOAuthReceivedId == "7")
        #expect(repository.deleteMemberOAuthReceivedGoogleAccessToken == nil)
        #expect(repository.deleteMemberOAuthReceivedKakaoAccessToken == "kakao-token")
    }

    @Test("repository.deleteMemberOAuth()가 에러를 던지면 그대로 전파한다")
    func deleteMemberOAuthPropagatesError() async {
        let repository = MockAuthRepository()
        repository.deleteMemberOAuthError = AuthTestError.boom
        let useCase = DeleteMemberOAuthUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            try await useCase.execute(
                memberOAuthId: "7",
                googleAccessToken: nil,
                kakaoAccessToken: nil
            )
        }
    }
}
