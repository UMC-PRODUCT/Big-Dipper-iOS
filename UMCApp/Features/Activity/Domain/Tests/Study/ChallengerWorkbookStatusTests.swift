//
//  ChallengerWorkbookStatusTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import Testing
@testable import ActivityDomain

// MARK: - Helpers

/// 단일 값 JSON 을 상태로 디코딩한다 (서버가 문자열 하나만 내려주는 필드 형태).
private func decodeStatus(from json: String) throws -> ChallengerWorkbookStatus {
    let data = Data(json.utf8)
    return try JSONDecoder().decode(ChallengerWorkbookStatus.self, from: data)
}

// MARK: - 서버 매퍼

@Suite("ChallengerWorkbookStatus — 서버 상태 매핑 (도메인 규칙)")
struct ChallengerWorkbookStatusTests {

    @Test(
        "서버 상태 문자열 4종이 대응 케이스로 매핑된다",
        arguments: [
            ("NOT_SUBMITTED", ChallengerWorkbookStatus.notSubmitted),
            ("IN_PROGRESS", .inProgress),
            ("PASS", .pass),
            ("FAIL", .fail)
        ]
    )
    func mapsServerContractValues(raw: String, expected: ChallengerWorkbookStatus) {
        #expect(ChallengerWorkbookStatus(serverStatus: raw) == expected)
    }

    @Test(
        "모르는 값과 누락은 .unknown 으로 폴백해 디코딩을 깨뜨리지 않는다",
        arguments: [
            String?.none,
            "",
            // 폐기된 WorkbookStatus 의 값 — 서버가 실수로 옛 enum 을 내려도 흡수한다.
            "SUBMITTED",
            "BEST"
        ]
    )
    func fallsBackToUnknown(raw: String?) {
        #expect(ChallengerWorkbookStatus(serverStatus: raw) == .unknown)
    }

    @Test("JSON 디코딩도 같은 폴백 규칙을 따른다")
    func decodingUsesSameFallback() throws {
        #expect(try decodeStatus(from: "\"PASS\"") == .pass)
        #expect(try decodeStatus(from: "\"NEW_SERVER_CASE\"") == .unknown)
    }

    // MARK: - 전송 / 필터 노출

    @Test(".unknown 은 서버로 되돌려 보내지 않는다")
    func unknownIsNotSentBack() {
        #expect(ChallengerWorkbookStatus.unknown.serverQueryValue == nil)
        #expect(ChallengerWorkbookStatus.pass.serverQueryValue == "PASS")
    }

    @Test(".unknown 은 필터 UI 후보에서 제외된다")
    func unknownIsExcludedFromFilters() {
        #expect(!ChallengerWorkbookStatus.filterableCases.contains(.unknown))
        #expect(ChallengerWorkbookStatus.filterableCases.count == 4)
    }

    // MARK: - 분류

    @Test(
        "평가 확정 여부는 통과/미통과에서만 참이다",
        arguments: [
            (ChallengerWorkbookStatus.pass, true),
            (.fail, true),
            (.inProgress, false),
            (.notSubmitted, false),
            (.unknown, false)
        ]
    )
    func isEvaluatedOnlyForDecidedStates(
        status: ChallengerWorkbookStatus,
        expected: Bool
    ) {
        #expect(status.isEvaluated == expected)
    }
}
