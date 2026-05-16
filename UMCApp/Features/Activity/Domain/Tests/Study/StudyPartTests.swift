//
//  StudyPartTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

@Suite("StudyPart — UMCPartType 매핑 (서버 contract)")
struct StudyPartTests {

    @Test(
        "각 StudyPart case 는 대응하는 UMCPartType 으로 매핑된다",
        arguments: [
            (StudyPart.ios, UMCPartType.front(type: .ios)),
            (StudyPart.android, UMCPartType.front(type: .android)),
            (StudyPart.web, UMCPartType.front(type: .web)),
            (StudyPart.spring, UMCPartType.server(type: .spring)),
            (StudyPart.nodejs, UMCPartType.server(type: .node)),
            (StudyPart.design, UMCPartType.design),
            (StudyPart.pm, UMCPartType.pm)
        ]
    )
    func partTypeMapping(part: StudyPart, expected: UMCPartType) {
        #expect(part.partType == expected)
    }
}
