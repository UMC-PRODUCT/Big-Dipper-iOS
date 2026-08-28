//
//  Profile+ProfileData.swift
//  MyPageDomain
//
//  Created by euijjang97 on 7/11/26.
//
//  정본 `CoreDomain.Profile` → MyPage `ProfileData` 매핑.
//  원본 MyPageData DTO의 `toProfileData()`(구 프로필 DTO, 삭제됨) 이식.
//

import CoreDomain
import Foundation
import UMCFoundation

public extension Profile {
    /// 정본 프로필을 마이페이지 화면 전체 데이터(`ProfileData`)로 변환합니다.
    func toProfileData() -> ProfileData {
        let visibleRecords = challengerRecords.filter { UMCPartType(apiValue: $0.part) != .admin }
        let latestRecord = visibleRecords.max { $0.gisu.intValue < $1.gisu.intValue }
            ?? challengerRecords.max { $0.gisu.intValue < $1.gisu.intValue }
        let latestRole = roles.max { $0.gisu.intValue < $1.gisu.intValue }

        let fallbackPart = latestRole?.responsiblePart
            .flatMap { UMCPartType(apiValue: $0) } ?? .admin

        let challengerInfo = ChallengerInfo(
            memberId: memberId,
            gen: latestRecord?.gisu ?? latestRole?.gisu ?? "0",
            name: latestRecord?.name ?? name,
            nickname: latestRecord?.nickname ?? nickname,
            schoolName: latestRecord?.schoolName ?? schoolName,
            profileImage: latestRecord?.profileImageLink?.nonEmpty ?? profileImageLink?.nonEmpty,
            part: UMCPartType(apiValue: latestRecord?.part ?? "") ?? fallbackPart
        )

        let challengeId = latestRecord?.challengerId.intValue
            ?? latestRole?.challengerId.intValue ?? 0

        return ProfileData(
            challengeId: challengeId,
            challengerInfo: challengerInfo,
            socialConnections: [],
            activityLogs: activityLogs(),
            profileLink: profileLinks()
        )
    }
}

private extension Profile {
    /// 외부 링크를 `SocialLinkType` 기반 `[ProfileLink]` 배열로 변환합니다.
    func profileLinks() -> [ProfileLink] {
        let mappedLinks: [SocialLinkType: String] = [
            .github: externalLinks?.github?.nonEmpty ?? "",
            .linkedin: externalLinks?.linkedIn?.nonEmpty ?? "",
            .blog: externalLinks?.blog?.nonEmpty ?? ""
        ]

        return SocialLinkType.allCases.map {
            ProfileLink(type: $0, url: mappedLinks[$0] ?? "")
        }
    }
}

// MARK: - Private String Helpers

private extension String {
    var intValue: Int { Int(self) ?? 0 }

    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
