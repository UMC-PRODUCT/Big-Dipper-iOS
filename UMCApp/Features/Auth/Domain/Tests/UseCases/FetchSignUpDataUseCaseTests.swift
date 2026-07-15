//
//  FetchSignUpDataUseCaseTests.swift
//  AuthDomainTests
//
//  Created by euijjang97 on 7/9/26.
//

import Testing
@testable import AuthDomain

@Suite("FetchSignUpDataUseCase — Repository 위임 검증")
struct FetchSignUpDataUseCaseTests {

    // MARK: - fetchSchools

    @Test("fetchSchools() 호출 시 repository.fetchSchools() 결과를 그대로 반환한다")
    func fetchSchoolsDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        let schools = [School(id: "7", name: "한양대학교"), School(id: "12", name: "숭실대학교")]
        repository.fetchSchoolsResult = .success(schools)
        let useCase = FetchSignUpDataUseCase(repository: repository)

        let result = try await useCase.fetchSchools()

        #expect(result == schools)
        #expect(repository.fetchSchoolsCallCount == 1)
    }

    @Test("repository.fetchSchools()가 에러를 던지면 그대로 전파한다")
    func fetchSchoolsPropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.fetchSchoolsResult = .failure(AuthTestError.boom)
        let useCase = FetchSignUpDataUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.fetchSchools()
        }
    }

    // MARK: - fetchTerms

    @Test("fetchTerms(type:) 호출 시 repository.fetchTerms(type:)에 파라미터를 그대로 전달하고 결과를 반환한다")
    func fetchTermsDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        let terms = Terms(
            id: "1",
            type: .service,
            link: "https://umc.dev/terms",
            isMandatory: true
        )
        repository.fetchTermsResult = .success(terms)
        let useCase = FetchSignUpDataUseCase(repository: repository)

        let result = try await useCase.fetchTerms(type: .service)

        #expect(result == terms)
        #expect(repository.fetchTermsCallCount == 1)
        #expect(repository.fetchTermsReceivedType == .service)
    }

    @Test("repository.fetchTerms(type:)가 에러를 던지면 그대로 전파한다")
    func fetchTermsPropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.fetchTermsResult = .failure(AuthTestError.boom)
        let useCase = FetchSignUpDataUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.fetchTerms(type: .privacy)
        }
    }
}
