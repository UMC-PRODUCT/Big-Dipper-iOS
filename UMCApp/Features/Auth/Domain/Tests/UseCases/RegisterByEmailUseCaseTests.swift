import Testing
@testable import AuthDomain

@Suite("RegisterByEmailUseCase — Repository 위임 검증")
struct RegisterByEmailUseCaseTests {

    @Test("execute() 호출 시 repository.registerByEmail()에 파라미터를 그대로 전달하고 결과를 반환한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        repository.registerByEmailResult = .success(RegisterByIdPwResult(memberId: "100"))
        let useCase = RegisterByEmailUseCase(repository: repository)
        let termsAgreements = [TermsAgreement(termsId: "1", isAgreed: true)]

        let result = try await useCase.execute(
            rawPassword: "P@ssw0rd!",
            name: "홍길동",
            nickname: "umc-hong",
            emailVerificationToken: "email-verification-token",
            schoolId: "7",
            termsAgreements: termsAgreements
        )

        #expect(result == RegisterByIdPwResult(memberId: "100"))
        #expect(repository.registerByEmailCallCount == 1)
        #expect(repository.registerByEmailReceivedRawPassword == "P@ssw0rd!")
        #expect(repository.registerByEmailReceivedName == "홍길동")
        #expect(repository.registerByEmailReceivedNickname == "umc-hong")
        #expect(
            repository.registerByEmailReceivedEmailVerificationToken == "email-verification-token"
        )
        #expect(repository.registerByEmailReceivedSchoolId == "7")
        #expect(repository.registerByEmailReceivedTermsAgreements == termsAgreements)
    }

    @Test("repository.registerByEmail()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.registerByEmailResult = .failure(AuthTestError.boom)
        let useCase = RegisterByEmailUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.execute(
                rawPassword: "P@ssw0rd!",
                name: "홍길동",
                nickname: "umc-hong",
                emailVerificationToken: "email-verification-token",
                schoolId: "7",
                termsAgreements: []
            )
        }
    }
}
