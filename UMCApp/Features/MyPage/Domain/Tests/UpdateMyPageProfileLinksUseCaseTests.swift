//
//  UpdateMyPageProfileLinksUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by 김동민 on 7/4/26.
//

import Testing
import Foundation
@testable import MyPageDomain

@Suite("UpdateMyPageProfileLinksUseCase — Repository 위임 검증")
struct UpdateMyPageProfileLinksUseCaseTests {

    @Test("execute(profileLinks:) 호출 시 repository.updateProfileLinks(_:)에 링크를 그대로 넘기고 결과를 반환한다")
    func delegatesToUpdateProfileLinks() async throws {
        let links = [
            ProfileLink(type: .github, url: "https://github.com/umc"),
            ProfileLink(type: .blog, url: "https://umc.dev"),
        ]
        let expected = makeStubProfileData(challengeId: 99)
        let mock = MockMyPageRepository()
        mock.updateProfileLinksResult = .success(expected)
        let useCase = UpdateMyPageProfileLinksUseCase(repository: mock)

        let result = try await useCase.execute(profileLinks: links)

        #expect(result == expected)
        #expect(mock.updateProfileLinksCallCount == 1)
        #expect(mock.updateProfileLinksReceivedLinks == links)
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let mock = MockMyPageRepository()
        mock.updateProfileLinksResult = .failure(MyPageTestError.boom)
        let useCase = UpdateMyPageProfileLinksUseCase(repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            _ = try await useCase.execute(profileLinks: [])
        }
    }
}
