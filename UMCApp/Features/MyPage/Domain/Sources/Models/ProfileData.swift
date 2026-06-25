//
//  ProfileData.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation
import UMCFoundation
import CoreDomain

/// 마이페이지에서 사용되는 프로필 전체 데이터를 나타내는 모델입니다.
public struct ProfileData: Identifiable, Equatable, Hashable {
    /// 프로필 데이터의 고유 식별자 (로컬 생성)
    public var id: UUID = .init()

    /// 챌린지 ID (서버 연동 등에서 사용)
    public var challengeId: Int

    /// 사용자 기본 정보 (이름, 학교, 기수 등)
    public var challengerInfo: ChallengerInfo

    /// 현재 연동된 소셜 계정 목록
    public var socialConnections: [SocialConnection]

    /// 활동 이력 목록 (기수별, 역할별)
    public var activityLogs: [ActivityLog]

    /// 외부 프로필 링크 목록 (Github, Blog 등)
    public var profileLink: [ProfileLink]

    /// 화면 표시용 연동 소셜 타입 목록
    public var socialConnected: [SocialType] {
        socialConnections.map(\.socialType)
    }

    public init(
        id: UUID = .init(),
        challengeId: Int,
        challengerInfo: ChallengerInfo,
        socialConnections: [SocialConnection],
        activityLogs: [ActivityLog],
        profileLink: [ProfileLink]
    ) {
        self.id = id
        self.challengeId = challengeId
        self.challengerInfo = challengerInfo
        self.socialConnections = socialConnections
        self.activityLogs = activityLogs
        self.profileLink = profileLink
    }
}

/// 연동된 소셜 계정의 서버 식별자와 타입을 나타내는 모델입니다.
public struct SocialConnection: Identifiable, Equatable, Hashable {
    /// OAuth 연동 ID
    public let memberOAuthId: Int

    /// 연동된 소셜 타입
    public let socialType: SocialType

    public var id: Int { memberOAuthId }

    public init(memberOAuthId: Int, socialType: SocialType) {
        self.memberOAuthId = memberOAuthId
        self.socialType = socialType
    }
}

/// 특정 기수/파트에서의 활동 기록을 나타내는 모델입니다.
public struct ActivityLog: Identifiable, Equatable, Hashable {
    /// 활동 기록의 고유 식별자
    public var id: UUID = .init()

    /// 활동 당시의 파트 (기획, 디자인, 서버 등)
    public var part: UMCPartType

    /// 활동 기수 (예: 11기, 12기)
    public var generation: Int

    /// 맡았던 역할 목록 (같은 기수/파트에서 여러 역할을 가질 수 있음)
    public var roles: [ManagementTeam]

    /// 가장 높은 우선순위의 역할 (기존 호환용)
    public var role: ManagementTeam {
        roles.max() ?? .challenger
    }

    public init(
        id: UUID = .init(),
        part: UMCPartType,
        generation: Int,
        role: ManagementTeam
    ) {
        self.id = id
        self.part = part
        self.generation = generation
        self.roles = [role]
    }

    public init(
        id: UUID = .init(),
        part: UMCPartType,
        generation: Int,
        roles: [ManagementTeam]
    ) {
        self.id = id
        self.part = part
        self.generation = generation
        self.roles = roles
    }
}

/// 외부 소셜/포트폴리오 링크 정보를 나타내는 모델입니다.
public struct ProfileLink: Identifiable, Equatable, Hashable {
    /// 링크 항목의 고유 식별자
    public var id: UUID = .init()

    /// 링크 타입 (Github, LinkedIn, Blog 등)
    public var type: SocialLinkType

    /// 실제 URL 문자열
    public var url: String

    /// 화면에 표시용 URL 문자열입니다.
    /// 'http://', 'https://' 스키마를 제거하여 깔끔하게 표시합니다.
    public var displayURL: String {
        url.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    public init(id: UUID = .init(), type: SocialLinkType, url: String) {
        self.id = id
        self.type = type
        self.url = url
    }
}
