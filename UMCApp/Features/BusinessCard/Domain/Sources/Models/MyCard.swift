//
//  MyCard.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation
import UMCFoundation

/// 내 디지털 명함 (마이페이지 v3 명세 MP-F01·F02).
///
/// 서버 유래 정수(`generation`·`memberNo`)는 전 레이어 String (절대규칙 #2).
/// `qrPayload`는 저장 필드가 아니라 `cardLink` 파생 — 서버가 주지 않는 값을 필드로 두면
/// 빈 상태가 생기므로 computed로 일원화한다 (설계 문서의 의도적 편차).
public struct MyCard: Equatable, Hashable, Sendable {

    // MARK: - Property

    public let memberId: String
    public let name: String
    public let nickname: String
    public let part: UMCPartType
    public let generation: String
    public let university: String
    public let email: String?
    public let github: String?
    public let blog: String?
    public let avatarURL: String?
    /// 표시용 멤버 번호. 현재는 memberId와 같고, 서버가 별도 번호를 주면 그 값을 담는다.
    public let memberNo: String?

    // MARK: - Init

    public init(
        memberId: String,
        name: String,
        nickname: String,
        part: UMCPartType,
        generation: String,
        university: String,
        email: String?,
        github: String?,
        blog: String?,
        avatarURL: String?,
        memberNo: String?
    ) {
        self.memberId = memberId
        self.name = name
        self.nickname = nickname
        self.part = part
        self.generation = generation
        self.university = university
        self.email = email
        self.github = github
        self.blog = blog
        self.avatarURL = avatarURL
        self.memberNo = memberNo
    }

    // MARK: - Computed Property

    /// 명함 프로필 딥링크.
    public var cardLink: CardLink {
        CardLink(memberId: memberId)
    }

    /// QR에 싣는 문자열. MP-F02 뒷면과 MP-F04가 반드시 같은 값을 쓴다.
    public var qrPayload: String {
        cardLink.urlString
    }
}
