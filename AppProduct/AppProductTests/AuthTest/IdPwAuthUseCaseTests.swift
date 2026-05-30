//
//  IdPwAuthUseCaseTests.swift
//  AppProductTests
//
//  Created by euijjang97 on 4/29/26.
//

@testable import AppProduct
import Foundation
import Testing

// MARK: - LoginByEmailUseCaseTests

struct LoginByEmailUseCaseTests {

    @Test("로그인 성공 시 결과를 반환하고 TokenStore 에 토큰을 저장한다")
    func loginSuccessSavesTokens() async throws {
        let repository = StubAuthRepository()
        let tokenStore = InMemoryTokenStore()
        let expected = LoginByIdPwResult(
            memberId: "999",
            tokenPair: TokenPair(
                accessToken: "email-access",
                refreshToken: "email-refresh"
            )
        )
        await repository.setLoginByEmailResult(.success(expected))

        let useCase = LoginByEmailUseCase(
            repository: repository,
            tokenStore: tokenStore
        )

        let result = try await useCase.execute(
            email: "reviewer@umc.dev",
            password: "umc12345!"
        )

        let saved = await tokenStore.snapshot()
        let lastRequest = await repository.lastLoginByEmailRequest

        #expect(result == expected)
        #expect(saved.accessToken == "email-access")
        #expect(saved.refreshToken == "email-refresh")
        #expect(saved.saveCallCount == 1)
        #expect(lastRequest?.email == "reviewer@umc.dev")
        #expect(lastRequest?.password == "umc12345!")
    }

    @Test("로그인 실패 시 에러를 그대로 전파하고 토큰을 저장하지 않는다")
    func loginFailurePropagatesErrorWithoutSavingTokens() async throws {
        let repository = StubAuthRepository()
        let tokenStore = InMemoryTokenStore()
        let serverError = RepositoryError.serverError(
            code: "AUTHENTICATION-0022",
            message: "이메일 또는 비밀번호가 올바르지 않습니다."
        )
        await repository.setLoginByEmailResult(.failure(serverError))

        let useCase = LoginByEmailUseCase(
            repository: repository,
            tokenStore: tokenStore
        )

        await #expect(throws: RepositoryError.self) {
            _ = try await useCase.execute(
                email: "wrong@umc.dev",
                password: "wrong"
            )
        }

        let saved = await tokenStore.snapshot()
        #expect(saved.accessToken == nil)
        #expect(saved.refreshToken == nil)
        #expect(saved.saveCallCount == 0)
    }
}

// MARK: - RegisterByEmailUseCaseTests

struct RegisterByEmailUseCaseTests {

    @Test("회원가입 성공 시 결과를 반환하고 TokenStore 에 토큰을 즉시 저장한다")
    func registerSuccessSavesTokensImmediately() async throws {
        let repository = StubAuthRepository()
        let tokenStore = InMemoryTokenStore()
        let expected = RegisterByIdPwResult(
            memberId: "1234",
            tokenPair: TokenPair(
                accessToken: "register-access",
                refreshToken: "register-refresh"
            )
        )
        await repository.setRegisterByEmailResult(.success(expected))

        let useCase = RegisterByEmailUseCase(
            repository: repository,
            tokenStore: tokenStore
        )

        let request = makeRegisterRequest()
        let result = try await useCase.execute(request: request)

        let saved = await tokenStore.snapshot()
        let lastRequest = await repository.lastRegisterByEmailRequest

        #expect(result == expected)
        #expect(saved.accessToken == "register-access")
        #expect(saved.refreshToken == "register-refresh")
        #expect(saved.saveCallCount == 1)
        #expect(lastRequest?.emailVerificationToken == request.emailVerificationToken)
        #expect(lastRequest?.schoolId == request.schoolId)
        #expect(lastRequest?.termsAgreements.count == request.termsAgreements.count)
    }

    @Test("회원가입 실패 시 에러를 그대로 전파하고 토큰을 저장하지 않는다")
    func registerFailurePropagatesErrorWithoutSavingTokens() async throws {
        let repository = StubAuthRepository()
        let tokenStore = InMemoryTokenStore()
        let serverError = RepositoryError.serverError(
            code: "AUTHENTICATION-0026",
            message: "이미 사용 중인 이메일입니다."
        )
        await repository.setRegisterByEmailResult(.failure(serverError))

        let useCase = RegisterByEmailUseCase(
            repository: repository,
            tokenStore: tokenStore
        )

        await #expect(throws: RepositoryError.self) {
            _ = try await useCase.execute(request: makeRegisterRequest())
        }

        let saved = await tokenStore.snapshot()
        #expect(saved.accessToken == nil)
        #expect(saved.refreshToken == nil)
        #expect(saved.saveCallCount == 0)
    }

    private func makeRegisterRequest() -> EmailRegisterRequestDTO {
        EmailRegisterRequestDTO(
            rawPassword: "umc12345!",
            name: "리뷰어",
            nickname: "리뷰",
            emailVerificationToken: "email-token",
            schoolId: "1",
            termsAgreements: [
                EmailRegisterTermsAgreementDTO(termsId: "1", agreed: true),
                EmailRegisterTermsAgreementDTO(termsId: "2", agreed: true)
            ]
        )
    }
}

// MARK: - CheckEmailAvailabilityUseCaseTests

struct CheckEmailAvailabilityUseCaseTests {

    @Test("Repository 가 사용 가능을 반환하면 true 를 그대로 전달한다")
    func availableEmailPassesThrough() async throws {
        let repository = StubAuthRepository()
        await repository.setCheckEmailAvailabilityResult(.success(true))
        let useCase = CheckEmailAvailabilityUseCase(repository: repository)

        let result = try await useCase.execute(email: "new@umc.dev")

        let lastQuery = await repository.lastCheckEmailAvailabilityQuery
        #expect(result == true)
        #expect(lastQuery == "new@umc.dev")
    }

    @Test("Repository 가 사용 불가를 반환하면 false 를 그대로 전달한다")
    func unavailableEmailPassesThrough() async throws {
        let repository = StubAuthRepository()
        await repository.setCheckEmailAvailabilityResult(.success(false))
        let useCase = CheckEmailAvailabilityUseCase(repository: repository)

        let result = try await useCase.execute(email: "reviewer@umc.dev")

        #expect(result == false)
    }

    @Test("Repository 에러는 그대로 전파된다")
    func errorPropagates() async throws {
        let repository = StubAuthRepository()
        let networkError = RepositoryError.serverError(
            code: "500",
            message: "서버 오류"
        )
        await repository.setCheckEmailAvailabilityResult(.failure(networkError))
        let useCase = CheckEmailAvailabilityUseCase(repository: repository)

        await #expect(throws: RepositoryError.self) {
            _ = try await useCase.execute(email: "any@umc.dev")
        }
    }
}

// MARK: - StubAuthRepository

/// 테스트용 AuthRepository 스텁
///
/// 필요한 메서드만 핸들러를 설정하고, 나머지는 호출 시 fatalError 로 실패시킵니다.
private actor StubAuthRepository: AuthRepositoryProtocol {

    // MARK: - Configurable Results

    private var loginByEmailResult: Result<LoginByIdPwResult, Error>?
    private var registerByEmailResult: Result<RegisterByIdPwResult, Error>?
    private var checkEmailAvailabilityResult: Result<Bool, Error>?

    // MARK: - Recorded Inputs

    private(set) var lastLoginByEmailRequest: EmailLoginRequestDTO?
    private(set) var lastRegisterByEmailRequest: EmailRegisterRequestDTO?
    private(set) var lastCheckEmailAvailabilityQuery: String?

    // MARK: - Setup

    func setLoginByEmailResult(_ result: Result<LoginByIdPwResult, Error>) {
        loginByEmailResult = result
    }

    func setRegisterByEmailResult(_ result: Result<RegisterByIdPwResult, Error>) {
        registerByEmailResult = result
    }

    func setCheckEmailAvailabilityResult(_ result: Result<Bool, Error>) {
        checkEmailAvailabilityResult = result
    }

    // MARK: - AuthRepositoryProtocol (tested)

    func loginByEmail(
        _ body: EmailLoginRequestDTO
    ) async throws -> LoginByIdPwResult {
        lastLoginByEmailRequest = body
        guard let result = loginByEmailResult else {
            fatalError("loginByEmailResult not configured")
        }
        return try result.get()
    }

    func registerByEmail(
        _ body: EmailRegisterRequestDTO
    ) async throws -> RegisterByIdPwResult {
        lastRegisterByEmailRequest = body
        guard let result = registerByEmailResult else {
            fatalError("registerByEmailResult not configured")
        }
        return try result.get()
    }

    func checkEmailAvailability(
        email: String
    ) async throws -> Bool {
        lastCheckEmailAvailabilityQuery = email
        guard let result = checkEmailAvailabilityResult else {
            fatalError("checkEmailAvailabilityResult not configured")
        }
        return try result.get()
    }

    // MARK: - AuthRepositoryProtocol (unused stubs)

    func loginKakao(
        accessToken: String,
        email: String
    ) async throws -> OAuthLoginResult {
        fatalError("loginKakao not used in these tests")
    }

    func loginApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        fatalError("loginApple not used in these tests")
    }

    func renewToken(
        refreshToken: String
    ) async throws -> TokenPair {
        fatalError("renewToken not used in these tests")
    }

    func getMyOAuth() async throws -> [MemberOAuth] {
        fatalError("getMyOAuth not used in these tests")
    }

    func addMemberOAuth(
        oAuthVerificationToken: String
    ) async throws -> [MemberOAuth] {
        fatalError("addMemberOAuth not used in these tests")
    }

    func deleteMemberOAuth(
        memberOAuthId: Int,
        googleAccessToken: String?,
        kakaoAccessToken: String?
    ) async throws {
        fatalError("deleteMemberOAuth not used in these tests")
    }

    func sendEmailVerification(
        email: String,
        purpose: EmailVerificationPurpose
    ) async throws -> String {
        fatalError("sendEmailVerification not used in these tests")
    }

    func resendEmailVerification(
        emailVerificationId: String
    ) async throws {
        fatalError("resendEmailVerification not used in these tests")
    }

    func resetPassword(
        emailVerificationToken: String,
        newPassword: String
    ) async throws {
        fatalError("resetPassword not used in these tests")
    }

    func verifyEmailCode(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String {
        fatalError("verifyEmailCode not used in these tests")
    }

    func register(
        request: RegisterRequestDTO
    ) async throws -> String {
        fatalError("register not used in these tests")
    }

    func registerExistingChallenger(
        code: String
    ) async throws {
        fatalError("registerExistingChallenger not used in these tests")
    }

    func getSchools() async throws -> [School] {
        fatalError("getSchools not used in these tests")
    }

    func getTerms(
        termsType: String
    ) async throws -> Terms {
        fatalError("getTerms not used in these tests")
    }

    func registerCredential(rawPassword: String) async throws {
        fatalError("registerCredential not used in these tests")
    }
}

// MARK: - InMemoryTokenStore

/// 테스트용 인메모리 TokenStore
private actor InMemoryTokenStore: TokenStore {
    private var accessToken: String?
    private var refreshToken: String?
    private var saveCallCount: Int = 0
    private var clearCallCount: Int = 0

    func getAccessToken() async -> String? {
        accessToken
    }

    func getRefreshToken() async -> String? {
        refreshToken
    }

    func save(accessToken: String, refreshToken: String) async throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        saveCallCount += 1
    }

    func clear() async throws {
        accessToken = nil
        refreshToken = nil
        clearCallCount += 1
    }

    func snapshot() -> (
        accessToken: String?,
        refreshToken: String?,
        saveCallCount: Int,
        clearCallCount: Int
    ) {
        (accessToken, refreshToken, saveCallCount, clearCallCount)
    }
}
