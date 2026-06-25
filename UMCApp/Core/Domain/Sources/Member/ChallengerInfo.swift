//
//  ChallengerInfo.swift
//  CoreDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation
import UMCFoundation

/// 챌린저(참여자) 정보 모델
///
/// 일정·검색·프로필 등 여러 Feature에서 공유하는 멤버 식별 모델입니다.
public struct ChallengerInfo: Identifiable, Equatable, Hashable {
    /// 고유 식별자
    public var id: UUID = .init()

    /// member ID (서버 응답 String 기준)
    public let memberId: String

    /// challenger ID (챌린저 엔티티 식별용, 서버 응답 String 기준)
    public let challengerId: String

    /// 기수 (예: 11기, 서버 응답 String 기준)
    public let gen: String

    /// 실명
    public let name: String

    /// 닉네임 (활동명)
    public let nickname: String

    /// 소속 학교명
    public let schoolName: String

    /// 프로필 이미지 URL (Optional)
    public let profileImage: String?

    /// UMC 파트 및 부서 정보 (iOS, Web, Server 등)
    public let part: UMCPartType

    /// 검색/선택 UI에서 사용하는 안정적인 행 식별 키
    ///
    /// 동일 memberId라도 기수/파트가 다르면 별도 항목으로 취급합니다.
    public var selectionKey: String {
        "\(memberId)|\(gen)|\(part.apiValue)"
    }

    public init(
        id: UUID = .init(),
        memberId: String,
        challengerId: String? = nil,
        gen: String,
        name: String,
        nickname: String,
        schoolName: String,
        profileImage: String?,
        part: UMCPartType
    ) {
        self.id = id
        self.memberId = memberId
        self.challengerId = challengerId ?? memberId
        self.gen = gen
        self.name = name
        self.nickname = nickname
        self.schoolName = schoolName
        self.profileImage = profileImage
        self.part = part
    }
}
