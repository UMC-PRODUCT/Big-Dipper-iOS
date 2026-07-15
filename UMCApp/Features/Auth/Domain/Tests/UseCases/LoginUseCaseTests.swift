//
//  LoginUseCaseTests.swift
//  AuthDomainTests
//
//  Created by euijjang97 on 7/9/26.
//

import Testing
@testable import AuthDomain

@Suite("LoginUseCase — Repository 위임 검증")
struct LoginUseCaseTests {

    // MARK: - Kakao

    @Test("executeKakao() 호출 시 repository.loginKakao()에 파라미터를 그대로 전달하고 결과를 반환한다")
    func executeKakaoDelegatesToRepository() async throws {
        let repository = MockAuthRepository()
        repository.loginKakaoResult = .success(.existingMember)
        let useCase = LoginUseCase(repository: repository)

        let result = try await useCase.executeKakao(accessToken: "kakao-token", email: "test@umc.dev")

        #expect(result == .existingMember)
        #expect(repository.loginKakaoCallCount == 1)
        #expect(repository.loginKakaoReceivedAccessToken == "kakao-token")
        #expect(repository.loginKakaoReceivedEmail == "test@umc.dev")
    }

    @Test("executeKakao()는 신규 회원 결과도 그대로 전달한다")
    func executeKakaoPropagatesNewMemberResult() async throws {
        let repository = MockAuthRepository()
        repository.loginKakaoResult = .success(.newMember(verificationToken: "verify-token"))
        let useCase = LoginUseCase(repository: repository)

        let result = try await useCase.executeKakao(accessToken: "kakao-token", email: "test@umc.dev")

        #expect(result == .newMember(verificationToken: "verify-token"))
    }

    @Test("repository.loginKakao()가 에러를 던지면 그대로 전파한다")
    func executeKakaoPropagatesError() async {
        let repository = MockAuthRepository()
        repository.loginKakaoResult = .failure(AuthTestError.boom)
        let useCase = LoginUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.executeKakao(accessToken: "kakao-token", email: "test@umc.dev")
        }
    }

    // MARK: - Apple

    @Test("executeApple() 호출 시 repository.loginApple()에 파라미터를 그대로 전달하고 결과를 반환한다")
    func executeAppleDelegatesToRepository() async throws {
        let repository = MockAuthRepository()
        repository.loginAppleResult = .success(.existingMember)
        let useCase = LoginUseCase(repository: repository)

        let result = try await useCase.executeApple(
            authorizationCode: "apple-code",
            email: "test@umc.dev",
            fullName: "홍길동"
        )

        #expect(result == .existingMember)
        #expect(repository.loginAppleCallCount == 1)
        #expect(repository.loginAppleReceivedAuthorizationCode == "apple-code")
        #expect(repository.loginAppleReceivedEmail == "test@umc.dev")
        #expect(repository.loginAppleReceivedFullName == "홍길동")
    }

    @Test("executeApple()는 email·fullName이 nil이어도 그대로 전달한다")
    func executeAppleAllowsNilOptionalFields() async throws {
        let repository = MockAuthRepository()
        repository.loginAppleResult = .success(.existingMember)
        let useCase = LoginUseCase(repository: repository)

        _ = try await useCase.executeApple(authorizationCode: "apple-code", email: nil, fullName: nil)

        #expect(repository.loginAppleReceivedEmail == nil)
        #expect(repository.loginAppleReceivedFullName == nil)
    }

    @Test("repository.loginApple()가 에러를 던지면 그대로 전파한다")
    func executeApplePropagatesError() async {
        let repository = MockAuthRepository()
        repository.loginAppleResult = .failure(AuthTestError.boom)
        let useCase = LoginUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.executeApple(authorizationCode: "apple-code", email: nil, fullName: nil)
        }
    }

    // MARK: - Google

    @Test("executeGoogle() 호출 시 repository.loginGoogle()에 파라미터를 그대로 전달하고 결과를 반환한다")
    func executeGoogleDelegatesToRepository() async throws {
        let repository = MockAuthRepository()
        repository.loginGoogleResult = .success(.existingMember)
        let useCase = LoginUseCase(repository: repository)

        let result = try await useCase.executeGoogle(accessToken: "google-token")

        #expect(result == .existingMember)
        #expect(repository.loginGoogleCallCount == 1)
        #expect(repository.loginGoogleReceivedAccessToken == "google-token")
    }

    @Test("repository.loginGoogle()가 에러를 던지면 그대로 전파한다")
    func executeGooglePropagatesError() async {
        let repository = MockAuthRepository()
        repository.loginGoogleResult = .failure(AuthTestError.boom)
        let useCase = LoginUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.executeGoogle(accessToken: "google-token")
        }
    }
}
