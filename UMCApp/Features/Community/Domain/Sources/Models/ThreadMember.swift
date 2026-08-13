//
//  ThreadMember.swift
//  CommunityDomain
//

import Foundation

/// 스레드 참여자 한 명.
///
/// 참여자 목록 화면이 쓰고, 초대(#1136)·`@`멘션 자동완성(#1140)이 같은 모델을 재사용한다.
/// 그래서 화면 전용 파생값(배지 문구 등)을 여기 넣지 않고 원본 필드만 들고 있는다.
public struct ThreadMember: Identifiable, Hashable, Sendable {

    // MARK: - Property

    /// 서버 `memberId`. 실시간 이벤트가 지목하는 식별자와 같은 값이다.
    public let id: String
    public let name: String
    /// 파트(예: `iOS`). 운영진처럼 파트가 없는 계정은 `nil` 로 온다.
    public let part: String?
    public let profileImageURL: String?
    public let role: ThreadMemberRole

    // MARK: - Init

    public init(
        id: String,
        name: String,
        part: String?,
        profileImageURL: String?,
        role: ThreadMemberRole
    ) {
        self.id = id
        self.name = name
        self.part = part
        self.profileImageURL = profileImageURL
        self.role = role
    }
}
