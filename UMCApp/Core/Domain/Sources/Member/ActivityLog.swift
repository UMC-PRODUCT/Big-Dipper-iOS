//
//  ActivityLog.swift
//  CoreDomain
//
//  Created by euijjang97 on 5/10/26.
//
//  MyPageDomain.ProfileData 에서 승격 (#1222) — 마이페이지 활동 목록과 명함 활동
//  카운트가 같은 모델·같은 파생 규칙을 봐야 해서 정본 레이어로 옮겼다.
//

import Foundation
import UMCFoundation

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
