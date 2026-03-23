//
//  ModifyProfileData.swift
//  AppProduct
//
//  Created by euijjang97 on 1/26/26.
//

import Foundation

/// 마이페이지에서 사용되는 프로필 전체 데이터를 나타내는 모델입니다.
struct ProfileData: Identifiable, Equatable, Hashable {
    /// 프로필 데이터의 고유 식별자 (로컬 생성)
    var id: UUID = .init()
    
    /// 챌린지 ID (서버 연동 등에서 사용)
    var challengeId: Int
    
    /// 사용자 기본 정보 (이름, 학교, 기수 등)
    var challangerInfo: ChallengerInfo
    
    /// 현재 연동된 소셜 계정 목록
    var socialConnections: [SocialConnection]
    
    /// 활동 이력 목록 (기수별, 역할별)
    var activityLogs: [ActivityLog]
    
    /// 외부 프로필 링크 목록 (Github, Blog 등)
    var profileLink: [ProfileLink]

    /// 화면 표시용 연동 소셜 타입 목록
    var socialConnected: [SocialType] {
        socialConnections.map(\.socialType)
    }
}

/// 연동된 소셜 계정의 서버 식별자와 타입을 나타내는 모델입니다.
struct SocialConnection: Identifiable, Equatable, Hashable {
    /// OAuth 연동 ID
    let memberOAuthId: Int

    /// 연동된 소셜 타입
    let socialType: SocialType

    var id: Int { memberOAuthId }
}

/// 특정 기수/파트에서의 활동 기록을 나타내는 모델입니다.
struct ActivityLog: Identifiable, Equatable, Hashable {
    /// 활동 기록의 고유 식별자
    var id: UUID = .init()

    /// 활동 당시의 파트 (기획, 디자인, 서버 등)
    var part: UMCPartType

    /// 활동 기수 (예: 11기, 12기)
    var generation: Int

    /// 맡았던 역할 목록 (같은 기수/파트에서 여러 역할을 가질 수 있음)
    var roles: [ManagementTeam]

    /// 가장 높은 우선순위의 역할 (기존 호환용)
    var role: ManagementTeam {
        roles.max() ?? .challenger
    }

    init(
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

    init(
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
struct ProfileLink: Identifiable, Equatable, Hashable {
    /// 링크 항목의 고유 식별자
    var id: UUID = .init()

    /// 링크 타입 (Github, LinkedIn, Blog 등)
    var type: SocialLinkType

    /// 실제 URL 문자열
    var url: String

    /// 화면에 표시용 URL 문자열입니다.
    /// 'http://', 'https://' 스키마를 제거하여 깔끔하게 표시합니다.
    var displayURL: String {
        url.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }
}




