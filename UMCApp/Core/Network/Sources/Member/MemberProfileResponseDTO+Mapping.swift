//
//  MemberProfileResponseDTO+Mapping.swift
//  CoreNetwork
//
//  Created by euijjang97 on 7/11/26.
//
//  `MemberProfileResponseDTO` → 도메인 모델 매핑.
//  - `toDomain()`: Auth가 소유했던 구 프로필 응답 DTO의 `toDomain()` 이식, 정본 `Profile` 전체를 채운다.
//  - `toMemberProfileSummary()`: MyPage가 소유했던 구 프로필 응답 DTO의 `toMemberProfileSummary()` 이식.
//

import CoreDomain
import Foundation

// MARK: - toDomain

extension MemberProfileResponseDTO {
    /// DTO → `Profile` 도메인 모델 변환.
    ///
    /// 역할(roles)과 챌린저 이력(challengerRecords) 양쪽에서 기수 번호를 모아 합집합을 구성하고,
    /// 챌린저 이력 중 숫자 기수가 가장 큰 레코드를 최신 기록으로 채택한다
    /// (Auth가 소유했던 구 프로필 응답 DTO의 `toDomain()` 이식).
    ///
    /// MyPage `updateProfileLinks()`/`patchMemberProfileImage()`가 응답을 `Profile`로 변환한 뒤
    /// `MyPageDomain`의 `Profile.toProfileData()` 확장으로 재매핑하기 위해 모듈 경계를 넘어 호출한다.
    public func toDomain() -> Profile {
        let generations = Set(roles.map(\.gisu) + challengerRecords.map(\.gisu))
            .filter { !$0.isEmpty && $0 != "0" }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }

        let latestRecord = challengerRecords.max {
            (Int($0.gisu) ?? 0) < (Int($1.gisu) ?? 0)
        }

        let profileRoles = roles.map {
            ProfileRole(
                id: $0.id,
                challengerId: $0.challengerId,
                gisu: $0.gisu,
                gisuId: $0.gisuId,
                roleType: $0.roleType,
                organizationType: $0.organizationType,
                organizationId: $0.organizationId,
                responsiblePart: $0.responsiblePart
            )
        }

        let domainChallengerRecords = challengerRecords.map { record in
            ProfileChallengerRecord(
                challengerId: record.challengerId,
                memberId: record.memberId,
                gisu: record.gisu,
                gisuId: record.gisuId,
                chapterId: record.chapterId,
                chapterName: record.chapterName,
                part: record.part,
                schoolId: record.schoolId,
                schoolName: record.schoolName,
                name: record.name,
                nickname: record.nickname,
                email: record.email,
                profileImageLink: record.profileImageLink,
                status: record.status,
                challengerPoints: record.challengerPoints.map {
                    ProfileChallengerPoint(
                        id: $0.id,
                        pointType: $0.pointType,
                        point: $0.point,
                        description: $0.description,
                        createdAt: $0.createdAt
                    )
                }
            )
        }

        let domainExternalLinks = profile.map {
            ProfileExternalLinks(
                id: $0.id,
                linkedIn: $0.linkedIn,
                instagram: $0.instagram,
                github: $0.github,
                blog: $0.blog,
                personal: $0.personal
            )
        }

        return Profile(
            memberId: id,
            name: name,
            nickname: nickname,
            generations: Array(generations),
            schoolId: schoolId,
            schoolName: schoolName,
            latestChallengerId: latestRecord?.challengerId,
            latestGisuId: latestRecord?.gisuId,
            chapterId: latestRecord?.chapterId,
            chapterName: latestRecord?.chapterName ?? "",
            responsiblePart: latestRecord?.part,
            roles: profileRoles,
            generationOrganizations: Self.buildGenerationOrganizations(
                records: challengerRecords,
                roles: roles
            ),
            email: email,
            profileImageLink: profileImageLink,
            status: status,
            externalLinks: domainExternalLinks,
            challengerRecords: domainChallengerRecords
        )
    }

    /// 챌린저 이력(학교/지부)을 우선 채택하고, 역할(roles)의 조직 정보로 누락된 값을 보강한다
    /// (Auth가 소유했던 구 프로필 응답 DTO의 `buildGenerationOrganizations(records:roles:)` 이식).
    private static func buildGenerationOrganizations(
        records: [MemberProfileChallengerRecordDTO],
        roles: [MemberProfileRoleDTO]
    ) -> [ProfileGenerationOrganization] {
        var byGeneration: [String: ProfileGenerationOrganization] = [:]

        for record in records where (Int(record.gisu) ?? 0) > 0 {
            byGeneration[record.gisu] = ProfileGenerationOrganization(
                gen: record.gisu,
                chapterId: record.chapterId,
                chapterName: record.chapterName,
                schoolId: (Int(record.schoolId) ?? 0) > 0 ? record.schoolId : nil,
                schoolName: record.schoolName.isEmpty ? nil : record.schoolName
            )
        }

        for role in roles where (Int(role.gisu) ?? 0) > 0 {
            let existing = byGeneration[role.gisu]
            let chapterId = role.organizationType == .chapter
                ? role.organizationId
                : existing?.chapterId
            let schoolId = role.organizationType == .school
                ? role.organizationId
                : existing?.schoolId
            byGeneration[role.gisu] = ProfileGenerationOrganization(
                gen: role.gisu,
                chapterId: chapterId,
                chapterName: existing?.chapterName,
                schoolId: schoolId,
                schoolName: existing?.schoolName
            )
        }

        return byGeneration.values.sorted { (Int($0.gen) ?? 0) < (Int($1.gen) ?? 0) }
    }
}

// MARK: - toMemberProfileSummary

extension MemberProfileResponseDTO {
    /// Notice 상세 작성자 표시용 프로필 요약 모델을 생성한다
    /// (MyPage `MyPageProfileResponseDTO.toMemberProfileSummary()` 이식). Task 5(MyPage)의
    /// `fetchMemberProfile(memberId:)`가 이 확장을 그대로 재사용한다.
    public func toMemberProfileSummary() -> MemberProfileSummary {
        let sortedRoles = roles
            .map {
                (
                    role: $0,
                    // 정본 DTO의 `gisu`는 decodeFlexibleStringOrEmpty로 항상 non-nil이므로,
                    // MyPage 원본의 `gisu ?? gisuId` 폴백을 "gisu가 비어 있으면 gisuId"로 이식한다.
                    generation: Int($0.gisu.isEmpty ? $0.gisuId : $0.gisu) ?? 0,
                    level: $0.roleType.level
                )
            }
            .sorted {
                if $0.level == $1.level {
                    return $0.generation > $1.generation
                }
                return $0.level > $1.level
            }

        let selectedRole = sortedRoles.first
        let latestRecordGeneration = challengerRecords
            .compactMap { Int($0.gisu) }
            .max() ?? 0
        let latestRecord = challengerRecords
            .sorted { Int($0.gisu) ?? 0 > Int($1.gisu) ?? 0 }
            .first
        let generation = selectedRole?.generation ?? latestRecordGeneration
        let roleName = selectedRole?.role.roleType.korean ?? "챌린저"
        let organizationName = latestRecord?.chapterName?.nonEmpty
            ?? latestRecord?.schoolName.nonEmpty

        return MemberProfileSummary(
            memberId: id,
            name: latestRecordName(),
            nickname: latestRecordNickname(),
            generation: generation,
            organizationName: organizationName,
            roleName: roleName,
            profileImageURL: profileImageLink
        )
    }
}

private extension MemberProfileResponseDTO {
    /// 기수(generation) 내림차순으로 정렬하여 가장 최신 기수의 이름을 반환한다.
    func latestRecordName() -> String {
        let sortedRecords = challengerRecords
            .sorted { Int($0.gisu) ?? 0 > Int($1.gisu) ?? 0 }
        return sortedRecords.first?.name ?? name
    }

    /// 기수(generation) 내림차순으로 정렬하여 가장 최신 기수의 닉네임을 반환한다.
    func latestRecordNickname() -> String {
        let sortedRecords = challengerRecords
            .sorted { Int($0.gisu) ?? 0 > Int($1.gisu) ?? 0 }
        return sortedRecords.first?.nickname ?? nickname
    }
}

// MARK: - Private String Helpers

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
