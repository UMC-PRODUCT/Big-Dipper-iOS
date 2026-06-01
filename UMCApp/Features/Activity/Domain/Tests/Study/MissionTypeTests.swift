//
//  MissionTypeTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("MissionType — 서버 contract 및 제출 방식 분기 (도메인 규칙)")
struct MissionTypeTests {

    // MARK: - init(rawValue:) (서버 contract)

    @Test(
        "init(rawValue:) 는 대소문자 무관하게 서버 contract 문자열을 enum 으로 변환한다",
        arguments: [
            ("LINK", MissionType.link),
            ("link", MissionType.link),
            ("Link", MissionType.link),
            ("MEMO", MissionType.memo),
            ("memo", MissionType.memo),
            ("PLAIN", MissionType.plain),
            ("plain", MissionType.plain)
        ]
    )
    func initFromServerStringCaseInsensitive(rawValue: String, expected: MissionType) {
        #expect(MissionType(rawValue: rawValue) == expected)
    }

    @Test(
        "init(rawValue:) 는 알 수 없는 문자열에 대해 .unknown 으로 fallback 한다",
        arguments: ["", "FOO", "submitted"]
    )
    func initFromUnknownStringFallsBackToUnknown(rawValue: String) {
        #expect(MissionType(rawValue: rawValue) == .unknown)
    }

    // MARK: - availableSubmissionTypes 분기

    @Test(".link 는 [.link] 제출만 허용한다")
    func linkAllowsOnlyLink() {
        #expect(MissionType.link.availableSubmissionTypes == [.link])
    }

    @Test(
        ".memo 와 .plain 은 [.completeOnly] 만 허용한다",
        arguments: [MissionType.memo, MissionType.plain]
    )
    func memoAndPlainAllowOnlyCompleteOnly(type: MissionType) {
        #expect(type.availableSubmissionTypes == [.completeOnly])
    }

    @Test(".unknown 은 모든 제출 방식을 허용한다 (fail-safe)")
    func unknownAllowsAll() {
        #expect(MissionType.unknown.availableSubmissionTypes == MissionSubmissionType.allCases)
    }

    // MARK: - defaultSubmissionType (availableSubmissionTypes 위임)

    @Test(
        "defaultSubmissionType 은 availableSubmissionTypes 의 첫 항목을 따른다",
        arguments: [
            (MissionType.link, MissionSubmissionType.link),
            (MissionType.memo, MissionSubmissionType.completeOnly),
            (MissionType.plain, MissionSubmissionType.completeOnly),
            (MissionType.unknown, MissionSubmissionType.link) // allCases.first
        ]
    )
    func defaultIsFirstOfAvailable(type: MissionType, expected: MissionSubmissionType) {
        #expect(type.defaultSubmissionType == expected)
    }
}
