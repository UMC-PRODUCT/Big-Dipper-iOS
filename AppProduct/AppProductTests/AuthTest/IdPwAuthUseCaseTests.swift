//
//  IdPwAuthUseCaseTests.swift
//  AppProductTests
//
//  Created by euijjang97 on 4/29/26.
//

@testable import AppProduct
import Foundation
import Testing

// MARK: - LoginByIdPwUseCaseTests

struct LoginByIdPwUseCaseTests {

    @Test("로그인 성공 시 결과를 반환하고 TokenStore 에 토큰을 저장한다")
    func loginSuccessSavesTokens() async throws {
        let repository = StubAuthRepository()
        let tokenStore = InMemoryTokenStore()
        let expected = LoginByIdPwResult(
            memberId: "999",
            tokenPair: TokenPair(
                accessToken: "id-pw-access",
                refreshToken: "id-pw-refresh"
            )
        )
        await repository.setLoginByIdPwResult(.success(expected))

        let useCase = LoginByIdPwUseCase(
            repository: repository,
            tokenStore: tokenStore
        )

        let result = try await useCase.execute(
            loginId: "reviewer",
            password: "umc12345!"
        )

        let saved = await tokenStore.snapshot()
        let lastRequest = await repository.lastLoginByIdPwRequest

        #expect(result == expected)
        #expect(saved.accessToken == "id-pw-access")
        #expect(saved.refreshToken == "id-pw-refresh")
        #expect(saved.saveCallCount == 1)
        #expect(lastRequest?.loginId == "reviewer")
        #expect(lastRequest?.password == "umc12345!")
    }

    @Test("로그인 실패 시 에러를 그대로 전파하고 토큰을 저장하지 않는다")
    func loginFailurePropagatesErrorWithoutSavingTokens() async throws {
        let repository = StubAuthRepository()
        let tokenStore = InMemoryTokenStore()
        let serverError = RepositoryError.serverError(
            code: "INVALID_CREDENTIALS",
            message: "아이디 또는 비밀번호가 올바르지 않습니다."
        )
        await repository.setLoginByIdPwResult(.failure(serverError))

        let useCase = LoginByIdPwUseCase(
            repository: repository,
            tokenStore: tokenStore
        )

        await #expect(throws: RepositoryError.self) {
            _ = try await useCase.execute(
                loginId: "wrong",
                password: "wrong"
            )
        }

        let saved = await tokenStore.snapshot()
        #expect(saved.accessToken == nil)
        #expect(saved.refreshToken == nil)
        #expect(saved.saveCallCount == 0)
    }
}

// MARK: - RegisterByIdPwUseCaseTests

struct RegisterByIdPwUseCaseTests {

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
        await repository.setRegisterByIdPwResult(.success(expected))

        let useCase = RegisterByIdPwUseCase(
            repository: repository,
            tokenStore: tokenStore
        )

        let request = makeRegisterRequest()
        let result = try await useCase.execute(request: request)

        let saved = await tokenStore.snapshot()
        let lastRequest = await repository.lastRegisterByIdPwRequest

        #expect(result == expected)
        #expect(saved.accessToken == "register-access")
        #expect(saved.refreshToken == "register-refresh")
        #expect(saved.saveCallCount == 1)
        #expect(lastRequest?.loginId == request.loginId)
        #expect(lastRequest?.emailVerificationToken == request.emailVerificationToken)
        #expect(lastRequest?.schoolId == request.schoolId)
        #expect(lastRequest?.termsAgreements.count == request.termsAgreements.count)
    }

    @Test("회원가입 실패 시 에러를 그대로 전파하고 토큰을 저장하지 않는다")
    func registerFailurePropagatesErrorWithoutSavingTokens() async throws {
        let repository = StubAuthRepository()
        let tokenStore = InMemoryTokenStore()
        let serverError = RepositoryError.serverError(
            code: "DUPLICATE_LOGIN_ID",
            message: "이미 사용 중인 아이디입니다."
        )
        await repository.setRegisterByIdPwResult(.failure(serverError))

        let useCase = RegisterByIdPwUseCase(
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

    private func makeRegisterRequest() -> RegisterByIdPwRequestDTO {
        RegisterByIdPwRequestDTO(
            emailVerificationToken: "email-token",
            loginId: "reviewer",
            name: "리뷰어",
            nickname: "리뷰",
            rawPassword: "umc12345!",
            schoolId: "1",
            termsAgreements: [
                RegisterByIdPwTermsAgreementDTO(termsId: "1", agreed: true),
                RegisterByIdPwTermsAgreementDTO(termsId: "2", agreed: true)
            ]
        )
    }
}

// MARK: - CheckLoginIdAvailabilityUseCaseTests

struct CheckLoginIdAvailabilityUseCaseTests {

    @Test("Repository 가 사용 가능을 반환하면 true 를 그대로 전달한다")
    func availableLoginIdPassesThrough() async throws {
        let repository = StubAuthRepository()
        await repository.setCheckLoginIdAvailabilityResult(.success(true))
        let useCase = CheckLoginIdAvailabilityUseCase(repository: repository)

        let result = try await useCase.execute(loginId: "freshUser")

        let lastQuery = await repository.lastCheckLoginIdAvailabilityQuery
        #expect(result == true)
        #expect(lastQuery == "freshUser")
    }

    @Test("Repository 가 사용 불가를 반환하면 false 를 그대로 전달한다")
    func unavailableLoginIdPassesThrough() async throws {
        let repository = StubAuthRepository()
        await repository.setCheckLoginIdAvailabilityResult(.success(false))
        let useCase = CheckLoginIdAvailabilityUseCase(repository: repository)

        let result = try await useCase.execute(loginId: "reviewer")

        #expect(result == false)
    }

    @Test("Repository 에러는 그대로 전파된다")
    func errorPropagates() async throws {
        let repository = StubAuthRepository()
        let networkError = RepositoryError.serverError(
            code: "500",
            message: "서버 오류"
        )
        await repository.setCheckLoginIdAvailabilityResult(.failure(networkError))
        let useCase = CheckLoginIdAvailabilityUseCase(repository: repository)

        await #expect(throws: RepositoryError.self) {
            _ = try await useCase.execute(loginId: "anyId")
        }
    }
}

// MARK: - StubAuthRepository

/// 테스트용 AuthRepository 스텁
///
/// 필요한 메서드만 핸들러를 설정하고, 나머지는 호출 시 fatalError 로 실패시킵니다.
private actor StubAuthRepository: AuthRepositoryProtocol {

    // MARK: - Configurable Results

    private var loginByIdPwResult: Result<LoginByIdPwResult, Error>?
    private var registerByIdPwResult: Result<RegisterByIdPwResult, Error>?
    private var checkLoginIdAvailabilityResult: Result<Bool, Error>?

    // MARK: - Recorded Inputs

    private(set) var lastLoginByIdPwRequest: LoginByIdPwRequestDTO?
    private(set) var lastRegisterByIdPwRequest: RegisterByIdPwRequestDTO?
    private(set) var lastCheckLoginIdAvailabilityQuery: String?

    // MARK: - Setup

    func setLoginByIdPwResult(_ result: Result<LoginByIdPwResult, Error>) {
        loginByIdPwResult = result
    }

    func setRegisterByIdPwResult(_ result: Result<RegisterByIdPwResult, Error>) {
        registerByIdPwResult = result
    }

    func setCheckLoginIdAvailabilityResult(_ result: Result<Bool, Error>) {
        checkLoginIdAvailabilityResult = result
    }

    // MARK: - AuthRepositoryProtocol (tested)

    func loginByIdPw(
        _ body: LoginByIdPwRequestDTO
    ) async throws -> LoginByIdPwResult {
        lastLoginByIdPwRequest = body
        guard let result = loginByIdPwResult else {
            fatalError("loginByIdPwResult not configured")
        }
        return try result.get()
    }

    func registerByIdPw(
        _ body: RegisterByIdPwRequestDTO
    ) async throws -> RegisterByIdPwResult {
        lastRegisterByIdPwRequest = body
        guard let result = registerByIdPwResult else {
            fatalError("registerByIdPwResult not configured")
        }
        return try result.get()
    }

    func checkLoginIdAvailability(
        loginId: String
    ) async throws -> Bool {
        lastCheckLoginIdAvailabilityQuery = loginId
        guard let result = checkLoginIdAvailabilityResult else {
            fatalError("checkLoginIdAvailabilityResult not configured")
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
        email: String
    ) async throws -> String {
        fatalError("sendEmailVerification not used in these tests")
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
