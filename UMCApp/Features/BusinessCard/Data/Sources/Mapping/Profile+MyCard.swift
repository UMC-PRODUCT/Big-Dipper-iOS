//
//  Profile+MyCard.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import UMCFoundation
import CoreDomain
import BusinessCardDomain

// 정본 `CoreDomain.Profile` → 명함 매핑.
// 파생 규칙은 MyPage의 `Profile.toProfileData()`(Profile+ProfileData.swift)와 동일하게 맞춘다
// — 명함과 프로필 카드가 다른 기수/파트를 보여주면 안 되기 때문.
public extension Profile {

    func toMyCard() -> MyCard {
        let visibleRecords = challengerRecords.filter { UMCPartType(apiValue: $0.part) != .admin }
        let latestRecord = visibleRecords.max { $0.gisu.intValue < $1.gisu.intValue }
            ?? challengerRecords.max { $0.gisu.intValue < $1.gisu.intValue }
        let latestRole = roles.max { $0.gisu.intValue < $1.gisu.intValue }

        let fallbackPart = latestRole?.responsiblePart
            .flatMap { UMCPartType(apiValue: $0) } ?? .admin

        // 서버 파트 문자열도 **못 읽을 수 있다.** 서버가 파트를 추가하면 앱이 갱신되기
        // 전까지 그렇다. 그때 `.admin` 으로 눌러 버리면 자기 명함이 「운영진」으로 보이고,
        // 그 값이 그대로 교환 페이로드에 실려 상대에게도 운영진으로 퍼진다.
        // 「없음」(빈 문자열·레코드 없음)과 「못 읽음」을 가르는 규칙은 수신 경로
        // (``MyCard/init(payload:)``)와 같다.
        let rawPart = (latestRecord?.part ?? latestRole?.responsiblePart ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let unrecognizedPart = (!rawPart.isEmpty && UMCPartType(apiValue: rawPart) == nil)
            ? rawPart
            : nil

        return MyCard(
            memberId: memberId,
            name: latestRecord?.name ?? name,
            nickname: latestRecord?.nickname ?? nickname,
            part: UMCPartType(apiValue: latestRecord?.part ?? "") ?? fallbackPart,
            generation: latestRecord?.gisu ?? latestRole?.gisu ?? "0",
            university: latestRecord?.schoolName ?? schoolName,
            email: (latestRecord?.email).flatMap(\.nonEmpty) ?? email.nonEmpty,
            github: externalLinks?.github?.nonEmpty,
            linkedIn: externalLinks?.linkedIn?.nonEmpty,
            blog: externalLinks?.blog?.nonEmpty,
            avatarURL: latestRecord?.profileImageLink?.nonEmpty ?? profileImageLink?.nonEmpty,
            partRaw: unrecognizedPart
        )
    }
}

// MARK: - Private String Helpers

// `intValue`/`nonEmpty`는 UMCFoundation에 없다(전 코드베이스 확인 2026-08-15).
// 유일한 정의가 MyPageDomain `Profile+ProfileData.swift`의 파일-로컬 private 확장이라
// BusinessCardData에서는 보이지 않는다. 파생 규칙을 정본과 동일하게 맞추기 위해
// 같은 구현을 여기 복제한다(크로스 피처 import 금지 — 승격은 소비자가 더 늘 때).
private extension String {
    var intValue: Int { Int(self) ?? 0 }

    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
