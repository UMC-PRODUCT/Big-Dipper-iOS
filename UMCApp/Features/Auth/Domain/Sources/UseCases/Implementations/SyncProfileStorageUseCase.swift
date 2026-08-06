//
//  SyncProfileStorageUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/10/26.
//

import CoreDomain
import Foundation
import UMCFoundation

/// 프로필 조회 결과를 `AppStorageKey` 기반 `UserDefaults`와 `UserSessionManager`에 동기화하는
/// UseCase 구현체.
///
/// 레거시 `HomeViewModel.saveProfileToStorage(_:)`(AppProduct)의 저장 규칙을 그대로 포팅한다.
public final class SyncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol {

    // MARK: - Property

    private let userSessionManager: UserSessionManager
    private let userDefaults: UserDefaults

    // MARK: - Init

    public init(userSessionManager: UserSessionManager, userDefaults: UserDefaults = .standard) {
        self.userSessionManager = userSessionManager
        self.userDefaults = userDefaults
    }

    // MARK: - Function

    public func execute(profile: Profile) {
        let latestRole = Self.latestHighestPriorityRole(in: profile.roles)
        let resolvedRole = ManagementTeam.highestPriority(in: profile.roles.map(\.roleType))
            ?? latestRole?.roleType
            ?? .challenger

        userDefaults.set(profile.memberId, forKey: AppStorageKey.memberId)
        userDefaults.set(profile.schoolId, forKey: AppStorageKey.schoolId)
        userDefaults.set(profile.schoolName, forKey: AppStorageKey.schoolName)
        userDefaults.set(profile.latestGisuId ?? "", forKey: AppStorageKey.gisuId)
        userDefaults.set(profile.latestChallengerId ?? "", forKey: AppStorageKey.challengerId)
        userDefaults.set(profile.chapterId ?? "", forKey: AppStorageKey.chapterId)
        userDefaults.set(profile.chapterName, forKey: AppStorageKey.chapterName)
        userDefaults.set(profile.responsiblePart ?? "", forKey: AppStorageKey.responsiblePart)
        userDefaults.set(
            latestRole?.organizationType.rawValue ?? OrganizationType.chapter.rawValue,
            forKey: AppStorageKey.organizationType
        )
        // 역할이 존재하면 그 역할의 organizationId(중앙 운영진처럼 nil이면 "")를 그대로 쓴다.
        // chapterId 폴백은 역할 자체가 없는 경우에만 적용한다 — 역할은 있지만 organizationId가
        // nil인 케이스(예: OrganizationType.central)에 무관한 chapterId를 채우지 않기 위함.
        let organizationId = latestRole.map { $0.organizationId ?? "" }
            ?? (profile.chapterId ?? "")
        userDefaults.set(organizationId, forKey: AppStorageKey.organizationId)
        userDefaults.set(resolvedRole.rawValue, forKey: AppStorageKey.memberRole)
        userDefaults.set(profile.roles.map(\.roleType.rawValue), forKey: AppStorageKey.memberRoles)
        userDefaults.set(
            Self.encodeGenerationOrganizations(profile.generationOrganizations),
            forKey: AppStorageKey.generationOrganizations
        )
        userDefaults.set(profile.isApproved, forKey: AppStorageKey.canAutoLogin)

        userSessionManager.updateRole(resolvedRole, allRoles: profile.roles.map(\.roleType))

        // 로그인 진입점 4곳이 모두 이 UseCase를 거치므로, memberId 확보 시점의 FCM 토큰
        // 재동기화 트리거는 여기 한 곳에서만 발송한다.
        NotificationCenter.default.post(name: .memberProfileUpdated, object: nil)
    }

    // MARK: - Private Function

    /// 숫자로 변환 가능한 기수(`gisu`) 중 가장 큰 값을 가진 역할들 중, 권한 레벨이 가장 높은
    /// 역할을 반환한다 (레거시 `Array<ChallengerRole>.latestHighestPriorityRole` 대응,
    /// AppProduct `HomeViewModel.swift:274-285`).
    private static func latestHighestPriorityRole(in roles: [ProfileRole]) -> ProfileRole? {
        guard let latestGisu = roles.compactMap({ Int($0.gisu) }).max() else {
            return nil
        }

        return roles
            .filter { Int($0.gisu) == latestGisu }
            .max { lhs, rhs in lhs.roleType < rhs.roleType }
    }

    private static func encodeGenerationOrganizations(
        _ contexts: [ProfileGenerationOrganization]
    ) -> String {
        guard let data = try? JSONEncoder().encode(contexts),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}
