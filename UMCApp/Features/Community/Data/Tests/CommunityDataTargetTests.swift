//
//  CommunityDataTargetTests.swift
//  CommunityDataTests
//

import Testing
@testable import CommunityData

@Suite("CommunityData 테스트 타깃 배선")
struct CommunityDataTargetTests {

    @Test("테스트 타깃이 CommunityData 를 import 할 수 있다")
    func targetIsWired() {
        #expect(Bool(true))
    }
}
