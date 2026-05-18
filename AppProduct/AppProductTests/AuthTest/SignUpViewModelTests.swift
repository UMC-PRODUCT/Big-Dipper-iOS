//
//  SignUpViewModelTests.swift
//  AppProductTests
//
//  Created by euijjang97 on 3/10/26.
//

@testable import AppProduct
import Testing

struct SignUpViewModelTests {

    @Test("회원가입 성공 후 카카오 로그인 컨텍스트로 세션을 복구한다")
    func restoreSessionWithKakaoAfterRegister() async throws {
        let loginUseCase = MockLoginUseCase()
        let viewModel = await MainActor.run {
            makeSUT(
                postRegisterLoginContext: .kakao(
                    accessToken: "kakao-access-token",
                    email: "umc@example.com"
                ),
                loginUseCase: loginUseCase
            )
        }

        await MainActor.run {
            viewModel.selectedSchool = School(id: "1", name: "UMC")
            viewModel.email = "umc@example.com"
        }
        try await viewModel.requestEmailVerification()
        try await viewModel.verifyEmailCode("123456")

        await viewModel.register()

        let snapshot = await loginUseCase.snapshot()
        let state = await MainActor.run { viewModel.registerState }

        #expect(state == .loaded("1"))
        #expect(snapshot.kakaoCallCount == 1)
        #expect(snapshot.lastKakaoAccessToken == "kakao-access-token")
        #expect(snapshot.lastKakaoEmail == "umc@example.com")
    }

    @Test("회원가입 성공 후 Apple 로그인 컨텍스트로 세션을 복구한다")
    func restoreSessionWithAppleAfterRegister() async throws {
        let loginUseCase = MockLoginUseCase()
        let viewModel = await MainActor.run {
            makeSUT(
                postRegisterLoginContext: .apple(
                    authorizationCode: "apple-code",
                    email: "apple@example.com",
                    fullName: "UMC Apple"
                ),
                loginUseCase: loginUseCase
            )
        }

        await MainActor.run {
            viewModel.selectedSchool = School(id: "1", name: "UMC")
            viewModel.email = "apple@example.com"
        }
        try await viewModel.requestEmailVerification()
        try await viewModel.verifyEmailCode("123456")

        await viewModel.register()

        let snapshot = await loginUseCase.snapshot()
        let state = await MainActor.run { viewModel.registerState }

        #expect(state == .loaded("1"))
        #expect(snapshot.appleCallCount == 1)
        #expect(snapshot.lastAppleAuthorizationCode == "apple-code")
        #expect(snapshot.lastAppleEmail == "apple@example.com")
        #expect(snapshot.lastAppleFullName == "UMC Apple")
    }

    @MainActor
    private func makeSUT(
        postRegisterLoginContext: PostRegisterLoginContext?,
        loginUseCase: MockLoginUseCase
    ) -> SignUpViewModel {
        SignUpViewModel(
            oAuthVerificationToken: "oauth-verification-token",
            postRegisterLoginContext: postRegisterLoginContext,
            sendEmailVerificationUseCase: MockSendEmailVerificationUseCase(),
            verifyEmailCodeUseCase: MockVerifyEmailCodeUseCase(),
            registerUseCase: MockRegisterUseCase(),
            loginUseCase: loginUseCase,
            fetchSignUpDataUseCase: MockFetchSignUpDataUseCase()
        )
    }
}

private actor MockLoginUseCase: LoginUseCaseProtocol {
    private var kakaoCallCount: Int = 0
    private var appleCallCount: Int = 0
    private var lastKakaoAccessToken: String?
    private var lastKakaoEmail: String?
    private var lastAppleAuthorizationCode: String?
    private var lastAppleEmail: String?
    private var lastAppleFullName: String?

    func executeKakao(
        accessToken: String,
        email: String
    ) async throws -> OAuthLoginResult {
        kakaoCallCount += 1
        lastKakaoAccessToken = accessToken
        lastKakaoEmail = email

        return .existingMember(
            tokenPair: TokenPair(
                accessToken: "saved-access-token",
                refreshToken: "saved-refresh-token"
            )
        )
    }

    func executeApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        appleCallCount += 1
        lastAppleAuthorizationCode = authorizationCode
        lastAppleEmail = email
        lastAppleFullName = fullName

        return .existingMember(
            tokenPair: TokenPair(
                accessToken: "saved-access-token",
                refreshToken: "saved-refresh-token"
            )
        )
    }

    func snapshot() -> (
        kakaoCallCount: Int,
        appleCallCount: Int,
        lastKakaoAccessToken: String?,
        lastKakaoEmail: String?,
        lastAppleAuthorizationCode: String?,
        lastAppleEmail: String?,
        lastAppleFullName: String?
    ) {
        (
            kakaoCallCount,
            appleCallCount,
            lastKakaoAccessToken,
            lastKakaoEmail,
            lastAppleAuthorizationCode,
            lastAppleEmail,
            lastAppleFullName
        )
    }
}

private struct MockRegisterUseCase: RegisterUseCaseProtocol {
    func execute(request: RegisterRequestDTO) async throws -> String {
        "1"
    }
}

private struct MockSendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol {
    func execute(email: String, purpose: EmailVerificationPurpose) async throws -> String {
        "email-verification-id"
    }
}

private struct MockVerifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol {
    func execute(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String {
        "verified-email-token"
    }
}

private struct MockFetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol {
    func fetchSchools() async throws -> [School] {
        []
    }

    func fetchTerms(termsType: String) async throws -> Terms {
        Terms(
            id: "1",
            link: "https://example.com",
            isMandatory: true,
            termsType: .service
        )
    }
}
