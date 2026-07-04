//
//  DeleteMemberUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by 김동민 on 7/4/26.
//

import Testing
import Foundation
@testable import MyPageDomain

@Suite("DeleteMemberUseCase — Repository 위임 검증")
struct DeleteMemberUseCaseTests {

    @Test("execute() 호출 시 repository.deleteMember()에 위임한다")
    func delegatesToDeleteMember() async throws {
        let mock = MockMyPageRepository()
        let useCase = DeleteMemberUseCase(repository: mock)

        try await useCase.execute()

        #expect(mock.deleteMemberCallCount == 1)
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let mock = MockMyPageRepository()
        mock.deleteMemberError = MyPageTestError.boom
        let useCase = DeleteMemberUseCase(repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            try await useCase.execute()
        }
    }
}
