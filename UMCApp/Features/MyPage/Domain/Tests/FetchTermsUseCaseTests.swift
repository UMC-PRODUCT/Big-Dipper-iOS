//
//  FetchTermsUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by 김동민 on 7/4/26.
//

import Testing
import Foundation
@testable import MyPageDomain

@Suite("FetchTermsUseCase — Repository 위임 검증")
struct FetchTermsUseCaseTests {

    @Test("execute(termsType:) 호출 시 repository.fetchTerms(termsType:)에 타입을 그대로 넘기고 결과를 반환한다")
    func delegatesToFetchTerms() async throws {
        let expected = MyPageTerms(id: "terms-42", link: "https://umc.dev/terms", isMandatory: true)
        let mock = MockMyPageRepository()
        mock.fetchTermsResult = .success(expected)
        let useCase = FetchTermsUseCase(repository: mock)

        let result = try await useCase.execute(termsType: "SERVICE")

        // MyPageTerms는 Equatable이 아니라 필드 단위로 비교한다.
        #expect(result.id == expected.id)
        #expect(result.link == expected.link)
        #expect(result.isMandatory == expected.isMandatory)
        #expect(mock.fetchTermsCallCount == 1)
        #expect(mock.fetchTermsReceivedTermsType == "SERVICE")
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let mock = MockMyPageRepository()
        mock.fetchTermsResult = .failure(MyPageTestError.boom)
        let useCase = FetchTermsUseCase(repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            _ = try await useCase.execute(termsType: "SERVICE")
        }
    }
}
