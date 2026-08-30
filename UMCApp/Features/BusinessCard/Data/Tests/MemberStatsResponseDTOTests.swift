//
//  MemberStatsResponseDTOTests.swift
//  BusinessCardDataTests
//
//  Created by JEONG on 8/30/26.
//

import Foundation
import Testing
@testable import BusinessCardData

@Suite("MemberStatsResponseDTO — 통합 카운트 디코딩")
struct MemberStatsResponseDTOTests {

    @Test("숫자로 내려와도 String으로 실린다 (절대규칙 #2·#3)")
    func absorbsNumberShape() throws {
        let dto = try JSONDecoder().decode(
            MemberStatsResponseDTO.self,
            from: Data("""
            {"receivedCardCount":12,"studyCount":"3","scrapCount":7}
            """.utf8)
        )

        #expect(dto.receivedCardCount == "12")
        #expect(dto.studyCount == "3")
        #expect(dto.scrapCount == "7")
    }

    /// 「0건」과 「못 셌다」가 같은 값이 되면 화면이 통신 실패를 0으로 단언한다 (#1222).
    @Test("0건은 0으로 실린다 — 결측과 섞이지 않는다")
    func zeroIsAValue() throws {
        let dto = try JSONDecoder().decode(
            MemberStatsResponseDTO.self,
            from: Data("""
            {"receivedCardCount":"0","studyCount":"0","scrapCount":"0"}
            """.utf8)
        )

        #expect(dto.receivedCardCount == "0")
    }
}
