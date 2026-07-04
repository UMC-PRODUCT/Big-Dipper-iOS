//
//  AddChallengerRecordUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by 김동민 on 7/4/26.
//

import Testing
import Foundation
@testable import MyPageDomain

@Suite("AddChallengerRecordUseCase — Repository 위임 검증")
struct AddChallengerRecordUseCaseTests {

    @Test("execute(code:) 호출 시 repository.addChallnegerRecord(code:)에 코드를 그대로 넘긴다")
    func delegatesWithCode() async throws {
        let mock = MockMyPageRepository()
        let useCase = AddChallengerRecordUseCase(repository: mock)

        try await useCase.execute(code: "UMC-2026")

        #expect(mock.addChallnegerRecordCallCount == 1)
        #expect(mock.addChallnegerRecordReceivedCode == "UMC-2026")
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let mock = MockMyPageRepository()
        mock.addChallnegerRecordError = MyPageTestError.boom
        let useCase = AddChallengerRecordUseCase(repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            try await useCase.execute(code: "UMC-2026")
        }
    }
}
