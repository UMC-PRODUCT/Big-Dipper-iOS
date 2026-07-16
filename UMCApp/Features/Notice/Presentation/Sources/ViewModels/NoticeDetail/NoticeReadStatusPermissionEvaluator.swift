//
//  NoticeReadStatusPermissionEvaluator.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import UMCFoundation
import NoticeDomain

/// 공지 대상과 사용자 역할을 기준으로 수신 확인 현황 접근 가능 여부를 계산합니다.
public struct NoticeReadStatusPermissionEvaluator {

    // MARK: - Role Sets

    private static let executiveRoles: Set<ManagementTeam> = [
        .superAdmin,
        .centralPresident,
        .centralVicePresident
    ]

    private static let centralOperationRoles: Set<ManagementTeam> = [
        .centralOperatingTeamMember,
        .centralEducationTeamMember
    ]

    private static let schoolAdminRoles: Set<ManagementTeam> = [
        .schoolPresident,
        .schoolVicePresident,
        .schoolPartLeader,
        .schoolEtcAdmin
    ]

    // MARK: - Function

    public static func canViewReadStatus(
        roles: [ManagementTeam],
        userChapterId: String?,
        userSchoolId: String?,
        targetAudience: TargetAudience
    ) -> Bool {
        let roleSet = Set(roles)

        if !roleSet.isDisjoint(with: executiveRoles) {
            return true
        }

        if let targetChapterId = targetAudience.chapterId {
            guard let userChapterId, !userChapterId.isEmpty else { return false }
            return roleSet.contains(.chapterPresident) && userChapterId == targetChapterId
        }

        if let targetSchoolId = targetAudience.schoolId {
            guard let userSchoolId, !userSchoolId.isEmpty else { return false }
            return !roleSet.isDisjoint(with: schoolAdminRoles) && userSchoolId == targetSchoolId
        }

        guard !targetAudience.generation.isEmpty && targetAudience.generation != "0" else {
            return false
        }

        return !roleSet.isDisjoint(with: centralOperationRoles)
    }
}
