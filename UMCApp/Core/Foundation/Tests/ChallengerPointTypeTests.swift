//
//  ChallengerPointTypeTests.swift
//  UMCFoundationTests
//
//  Created by jaewon Lee on 6/17/26.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("ChallengerPointType — 상벌점 유형 규칙 (도메인 규칙)")
struct ChallengerPointTypeTests {

    // MARK: - rawValue Mapping

    @Test(
        "서버 rawValue ↔ enum 매핑이 정확하다",
        arguments: [
            ("BEST_WORKBOOK", ChallengerPointType.bestWorkbook),
            ("WARNING", .warning),
            ("OUT", .out),
            ("CUSTOM", .custom),
            ("STUDY_ABSENT", .studyAbsent),
            ("SCHOOL_CORE_TASK_NOT_COMPLETED", .schoolCoreTaskNotCompleted)
        ]
    )
    func rawValueMapping(raw: String, expected: ChallengerPointType) {
        #expect(ChallengerPointType(rawValue: raw) == expected)
        #expect(expected.rawValue == raw)
    }

    @Test("알 수 없는 rawValue 는 nil 을 반환한다")
    func unknownRawValueReturnsNil() {
        #expect(ChallengerPointType(rawValue: "NOT_A_POINT") == nil)
    }

    // MARK: - defaultPointValue

    @Test(
        "유형별 기본 배점이 정확하다",
        arguments: [
            (ChallengerPointType.bestWorkbook, 2),
            (.blogChallenge, 3),
            (.custom, 0),
            (.studyAbsent, -4),
            (.eventNoShow, -10)
        ]
    )
    func defaultPointValueMapping(type: ChallengerPointType, expected: Int) {
        #expect(type.defaultPointValue == expected)
    }

    // MARK: - isReward

    @Test(
        "기본 배점이 양수인 유형은 상점(isReward=true)",
        arguments: [
            ChallengerPointType.bestWorkbook,
            .blogChallenge,
            .umcEventReview
        ]
    )
    func positiveDefaultIsReward(type: ChallengerPointType) {
        #expect(type.isReward == true)
    }

    @Test(
        "기본 배점이 0 이하인 유형은 상점이 아니다(isReward=false)",
        arguments: [
            ChallengerPointType.custom,
            .studyAbsent,
            .eventNoShow
        ]
    )
    func nonPositiveDefaultIsNotReward(type: ChallengerPointType) {
        #expect(type.isReward == false)
    }

    // MARK: - isCustom

    @Test("custom 유형만 isCustom=true")
    func onlyCustomIsCustom() {
        #expect(ChallengerPointType.custom.isCustom == true)
    }

    @Test(
        "custom 이 아닌 유형은 isCustom=false",
        arguments: [
            ChallengerPointType.bestWorkbook,
            .warning,
            .studyLate
        ]
    )
    func nonCustomIsNotCustom(type: ChallengerPointType) {
        #expect(type.isCustom == false)
    }

    // MARK: - minimumRequiredLevel

    @Test(
        "유형별 최소 권한 레벨이 정확하다",
        arguments: [
            (ChallengerPointType.bestWorkbook, 20),
            (.partLeadFeedbackLate, 30),
            (.schoolCoreMeetingAbsent, 50)
        ]
    )
    func minimumRequiredLevelMapping(type: ChallengerPointType, expected: Int) {
        #expect(type.minimumRequiredLevel == expected)
    }

    // MARK: - availableTypes(for:)

    @Test("availableTypes 는 항상 warning/out 을 제외한다")
    func availableTypesExcludeWarningAndOut() {
        let available = ChallengerPointType.availableTypes(for: 110)

        #expect(available.contains(.warning) == false)
        #expect(available.contains(.out) == false)
    }

    @Test("레벨 20 은 레벨 30/50 전용 유형을 포함하지 않는다")
    func level20ExcludesHigherLevelTypes() {
        let available = ChallengerPointType.availableTypes(for: 20)

        #expect(available.contains(.bestWorkbook) == true)
        #expect(available.contains(.partLeadFeedbackLate) == false)
        #expect(available.contains(.schoolCoreMeetingAbsent) == false)
    }

    @Test("레벨 30 은 파트장 전용 유형까지 포함한다")
    func level30IncludesPartLeaderType() {
        let available = ChallengerPointType.availableTypes(for: 30)

        #expect(available.contains(.partLeadFeedbackLate) == true)
        #expect(available.contains(.schoolCoreMeetingAbsent) == false)
    }

    @Test("레벨 50 은 회장단 전용 유형까지 포함한다")
    func level50IncludesSchoolCoreType() {
        let available = ChallengerPointType.availableTypes(for: 50)

        #expect(available.contains(.schoolCoreMeetingAbsent) == true)
    }

    @Test("최소 레벨(0)에서는 부여 가능한 유형이 없다")
    func level0HasNoAvailableTypes() {
        #expect(ChallengerPointType.availableTypes(for: 0).isEmpty)
    }

    // MARK: - 레거시 예외 동작 (warning / out)

    @Test(
        "warning/out 은 벌점 개념이지만 레거시 호환으로 양수 배점 → isReward=true (의도적 보존)",
        arguments: [
            ChallengerPointType.warning,
            ChallengerPointType.out
        ]
    )
    func warningAndOutHavePositiveDefaultForLegacy(type: ChallengerPointType) {
        #expect(type.defaultPointValue > 0)
        #expect(type.isReward == true)
    }
}
