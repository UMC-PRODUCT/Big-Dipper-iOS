//
//  Profile+ProfileData.swift
//  MyPageDomain
//
//  정본 `CoreDomain.Profile` → MyPage `ProfileData` 매핑.
//  원본 MyPageData DTO의 `toProfileData()`(구 `MyPageProfileDTO.swift`, 삭제됨) 이식.
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

        return ProfileData(
            challengeId: latestRecord?.challengerId.intValue ?? latestRole?.challengerId.intValue ?? 0,
            challengerInfo: challengerInfo,
            socialConnections: [],
            activityLogs: activityLogs(),
            profileLink: profileLinks()
        )
    }
}

private extension Profile {
    /// 역할(roles)·챌린저 이력(challengerRecords)을 병합해 기수 내림차순 활동 이력을 구성합니다.
    func activityLogs() -> [ActivityLog] {
        let roleLogs = roles.map { role in
            ActivityLog(
                part: role.responsiblePart.flatMap { UMCPartType(apiValue: $0) } ?? .admin,
                generation: role.gisu.intValue,
                role: role.roleType
            )
        }

        let challengerLogs = challengerRecords.compactMap { record -> ActivityLog? in
            guard let part = UMCPartType(apiValue: record.part), part != .admin else {
                return nil
            }

            return ActivityLog(
                part: part,
                generation: record.gisu.intValue,
                role: .challenger
            )
        }

        let merged = mergeAdminLogs(roleLogs + challengerLogs)

        return merged.sorted { lhs, rhs in
            if lhs.generation == rhs.generation {
                return lhs.role > rhs.role
            }
            return lhs.generation > rhs.generation
        }
    }

    /// 같은 기수의 Admin 이력을 하나로 병합합니다.
    func mergeAdminLogs(_ logs: [ActivityLog]) -> [ActivityLog] {
        var adminByGen: [Int: [ManagementTeam]] = [:]
        var result: [ActivityLog] = []

        for log in logs {
            if log.part == .admin {
                adminByGen[log.generation, default: []].append(log.role)
            } else {
                result.append(log)
            }
        }

        for (gen, adminRoles) in adminByGen {
            let sortedRoles = adminRoles.sorted(by: >)
            result.append(ActivityLog(
                part: .admin,
                generation: gen,
                roles: sortedRoles
            ))
        }

        return result
    }

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
