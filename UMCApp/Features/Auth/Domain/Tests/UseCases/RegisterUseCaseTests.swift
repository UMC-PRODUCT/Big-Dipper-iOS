import Testing
@testable import AuthDomain

@Suite("RegisterUseCase — Repository 위임 검증")
struct RegisterUseCaseTests {

    @Test("execute() 호출 시 repository.register()에 파라미터를 그대로 전달하고 결과를 반환한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        repository.registerResult = .success(
            RegisterResult(memberId: "100", sessionEstablished: true)
        )
        let useCase = RegisterUseCase(repository: repository)
        let termsAgreements = [TermsAgreement(termsId: "1", isAgreed: true)]

        let result = try await useCase.execute(
            oAuthVerificationToken: "oauth-verification-token",
            name: "홍길동",
            nickname: "umc-hong",
            emailVerificationToken: "email-verification-token",
            schoolId: "7",
            profileImageId: "img-1",
            termsAgreements: termsAgreements
        )

        #expect(result == RegisterResult(memberId: "100", sessionEstablished: true))
        #expect(repository.registerCallCount == 1)
        #expect(repository.registerReceivedOAuthVerificationToken == "oauth-verification-token")
        #expect(repository.registerReceivedName == "홍길동")
        #expect(repository.registerReceivedNickname == "umc-hong")
        #expect(repository.registerReceivedEmailVerificationToken == "email-verification-token")
        #expect(repository.registerReceivedSchoolId == "7")
        #expect(repository.registerReceivedProfileImageId == "img-1")
        #expect(repository.registerReceivedTermsAgreements == termsAgreements)
    }

    @Test("execute()는 profileImageId가 nil이어도 그대로 전달한다")
    func executeAllowsNilProfileImageId() async throws {
        let repository = MockAuthRegistrationRepository()
        repository.registerResult = .success(
            RegisterResult(memberId: "100", sessionEstablished: false)
        )
        let useCase = RegisterUseCase(repository: repository)

        let result = try await useCase.execute(
            oAuthVerificationToken: "oauth-verification-token",
            name: "홍길동",
            nickname: "umc-hong",
            emailVerificationToken: "email-verification-token",
            schoolId: "7",
            profileImageId: nil,
            termsAgreements: []
        )

        #expect(result.sessionEstablished == false)
        #expect(repository.registerReceivedProfileImageId == nil)
    }

    @Test("repository.register()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.registerResult = .failure(AuthTestError.boom)
        let useCase = RegisterUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.execute(
                oAuthVerificationToken: "oauth-verification-token",
                name: "홍길동",
                nickname: "umc-hong",
                emailVerificationToken: "email-verification-token",
                schoolId: "7",
                profileImageId: nil,
                termsAgreements: []
            )
        }
    }
}
