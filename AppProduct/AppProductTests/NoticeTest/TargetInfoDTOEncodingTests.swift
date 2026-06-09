//
//  TargetInfoDTOEncodingTests.swift
//  AppProductTests
//
//  공지 작성(POST /api/v1/notices) 요청의 targetInfo 인코딩 계약 검증.
//  - 챌린저 5케이스: targetNoticeTab == "CHALLENGER" 키 항상 포함 (400 회귀 가드)
//  - 운영진 3시나리오: CENTRAL_MEMBER / SCHOOL_CORE / SCHOOL_PART_LEADER
//  - null 규칙: targetGisuId<=0 → null, targetParts 빈배열 → null
//

@testable import AppProduct
import Foundation
import Testing

// MARK: - Helpers

/// `JSONEncoder` 결과를 키 순서에 의존하지 않게 `[String: Any]` 로 파싱한다.
/// 인코더의 `outputFormatting` 정렬에 의존하지 않기 위해 JSONSerialization 사용.
///
/// `TargetInfoDTO` 의 `Codable` 채택이 main-actor 격리(SWIFT_DEFAULT_ACTOR_ISOLATION
/// = MainActor)라서 인코딩을 메인 액터에서 수행한다.
@MainActor
private func encodeToJSONObject(_ dto: TargetInfoDTO) throws -> [String: Any] {
    let data = try JSONEncoder().encode(dto)
    let object = try JSONSerialization.jsonObject(with: data)
    return try #require(object as? [String: Any])
}

/// 챌린저 `.all` 케이스 — `targetGisuId = 0` (null 규칙과 contract 키 공존 검증용).
private func makeChallengerAll(schoolId: Int? = nil) -> TargetInfoDTO {
    TargetInfoDTO(
        targetGisuId: 0,
        targetChapterId: nil,
        targetSchoolId: schoolId,
        targetParts: nil as [UMCPartType]?,
        targetNoticeTab: StaffNoticeTab.challengerServerValue
    )
}

/// 챌린저 `.central` 케이스.
private func makeChallengerCentral(
    gisuId: Int = 14,
    chapterId: Int? = nil,
    schoolId: Int? = nil,
    parts: [UMCPartType]? = nil
) -> TargetInfoDTO {
    TargetInfoDTO(
        targetGisuId: gisuId,
        targetChapterId: chapterId,
        targetSchoolId: schoolId,
        targetParts: parts,
        targetNoticeTab: StaffNoticeTab.challengerServerValue
    )
}

/// 챌린저 `.branch` 케이스.
private func makeChallengerBranch(
    gisuId: Int = 14,
    chapterId: Int? = 7,
    parts: [UMCPartType]? = nil
) -> TargetInfoDTO {
    TargetInfoDTO(
        targetGisuId: gisuId,
        targetChapterId: chapterId,
        targetSchoolId: nil,
        targetParts: parts,
        targetNoticeTab: StaffNoticeTab.challengerServerValue
    )
}

/// 챌린저 `.school` 케이스.
private func makeChallengerSchool(
    gisuId: Int = 14,
    schoolId: Int? = 3,
    parts: [UMCPartType]? = nil
) -> TargetInfoDTO {
    TargetInfoDTO(
        targetGisuId: gisuId,
        targetChapterId: nil,
        targetSchoolId: schoolId,
        targetParts: parts,
        targetNoticeTab: StaffNoticeTab.challengerServerValue
    )
}

/// 챌린저 `.part` 케이스 — 단일 파트 지정.
private func makeChallengerPart(
    gisuId: Int = 14,
    part: UMCPartType = .front(type: .ios)
) -> TargetInfoDTO {
    TargetInfoDTO(
        targetGisuId: gisuId,
        targetChapterId: nil,
        targetSchoolId: nil,
        targetParts: [part],
        targetNoticeTab: StaffNoticeTab.challengerServerValue
    )
}

/// 운영진 시나리오 — 임의 탭 값을 받는 빌더 (buildTargetInfo의 `.management` 형태 모사).
private func makeManagement(
    gisuId: Int = 14,
    schoolId: Int? = nil,
    parts: [UMCPartType]? = nil,
    serverTab: String
) -> TargetInfoDTO {
    TargetInfoDTO(
        targetGisuId: gisuId,
        targetChapterId: nil,
        targetSchoolId: schoolId,
        targetParts: parts,
        targetNoticeTab: serverTab
    )
}

// MARK: - 챌린저 contract 키 (400 회귀 가드)

@Suite("TargetInfoDTO — 공지 작성 인코딩 (도메인 규칙)")
@MainActor
struct TargetInfoDTOEncodingTests {

    @Test("챌린저 .all (targetGisuId 0) 인코딩 시 targetNoticeTab 키가 CHALLENGER 로 포함된다")
    func challengerAllEmitsChallengerTab() throws {
        let json = try encodeToJSONObject(makeChallengerAll())

        #expect(json["targetNoticeTab"] as? String == "CHALLENGER")
    }

    @Test("챌린저 .all 은 targetGisuId 가 null 이어도 targetNoticeTab 은 그대로 출력된다")
    func challengerAllNullGisuStillEmitsTab() throws {
        let json = try encodeToJSONObject(makeChallengerAll())

        // null 규칙(targetGisuId<=0 → null)과 contract 키가 충돌하지 않음을 고정.
        #expect(json["targetGisuId"] is NSNull)
        #expect(json["targetNoticeTab"] as? String == "CHALLENGER")
    }

    @Test(
        "챌린저 5케이스 모두 targetNoticeTab 키가 CHALLENGER 로 포함된다",
        arguments: [
            "all", "central", "branch", "school", "part"
        ]
    )
    func challengerAllCasesEmitChallengerTab(caseName: String) throws {
        let dto: TargetInfoDTO = switch caseName {
        case "all":     makeChallengerAll()
        case "central": makeChallengerCentral()
        case "branch":  makeChallengerBranch()
        case "school":  makeChallengerSchool()
        default:        makeChallengerPart()
        }

        let json = try encodeToJSONObject(dto)

        #expect(json.keys.contains("targetNoticeTab"))
        #expect(json["targetNoticeTab"] as? String == "CHALLENGER")
    }

    // MARK: - 운영진 3시나리오 회귀 (바이트 동일 보장)

    @Test(
        "운영진 시나리오는 각 서버 탭 값을 그대로 인코딩한다",
        arguments: [
            ("CENTRAL_MEMBER", StaffNoticeTab.centralMember.rawValue),
            ("SCHOOL_CORE", StaffNoticeTab.schoolCore.rawValue),
            ("SCHOOL_PART_LEADER", StaffNoticeTab.schoolPartLeader.rawValue)
        ]
    )
    func managementScenariosEmitOwnTab(expected: String, serverTab: String) throws {
        let json = try encodeToJSONObject(
            makeManagement(serverTab: serverTab)
        )

        #expect(json["targetNoticeTab"] as? String == expected)
    }

    // MARK: - null 규칙 회귀 가드

    @Test("targetGisuId 가 0 이하면 targetGisuId 키는 null 이다", arguments: [0, -1])
    func nonPositiveGisuEncodesNull(gisuId: Int) throws {
        let json = try encodeToJSONObject(
            makeManagement(gisuId: gisuId, serverTab: "CENTRAL_MEMBER")
        )

        #expect(json["targetGisuId"] is NSNull)
    }

    @Test("targetGisuId 가 양수면 정수로 인코딩된다")
    func positiveGisuEncodesNumber() throws {
        let json = try encodeToJSONObject(
            makeManagement(gisuId: 14, serverTab: "CENTRAL_MEMBER")
        )

        #expect(json["targetGisuId"] as? Int == 14)
    }

    @Test("targetParts 가 nil 이면 targetParts 키는 null 이다")
    func nilPartsEncodesNull() throws {
        let json = try encodeToJSONObject(
            makeChallengerCentral(parts: nil)
        )

        #expect(json["targetParts"] is NSNull)
    }

    @Test("targetParts 가 빈 배열이면 targetParts 키는 null 이다")
    func emptyPartsEncodesNull() throws {
        let json = try encodeToJSONObject(
            makeChallengerCentral(parts: [])
        )

        #expect(json["targetParts"] is NSNull)
    }

    @Test("targetParts 에 값이 있으면 apiValue 배열로 인코딩된다")
    func nonEmptyPartsEncodesApiValues() throws {
        let json = try encodeToJSONObject(
            makeChallengerPart(part: .front(type: .ios))
        )

        #expect(json["targetParts"] as? [String] == ["IOS"])
        // 파트 지정 케이스에서도 contract 키는 유지.
        #expect(json["targetNoticeTab"] as? String == "CHALLENGER")
    }
}
