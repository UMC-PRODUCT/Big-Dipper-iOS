//
//  CommunityPresentationTargetTests.swift
//  CommunityPresentationTests
//

import Testing
@testable import CommunityPresentation

@Suite("CommunityPresentation 테스트 타깃 배선")
struct CommunityPresentationTargetTests {

    @Test("테스트 타깃이 CommunityPresentation 을 import 할 수 있다")
    func targetIsWired() {
        #expect(Bool(true))
    }
}
