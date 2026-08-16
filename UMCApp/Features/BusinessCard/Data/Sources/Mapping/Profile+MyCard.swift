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
            avatarURL: latestRecord?.profileImageLink?.nonEmpty ?? profileImageLink?.nonEmpty
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
