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
/// 서버 유래 정수(`generation`)는 전 레이어 String (절대규칙 #2).
/// `qrPayload`는 저장 필드가 아니라 `cardLink` 파생 — 서버가 주지 않는 값을 필드로 두면
/// 빈 상태가 생기므로 computed로 일원화한다 (설계 문서의 의도적 편차).
public struct MyCard: Equatable, Hashable, Sendable {

    // MARK: - Property

    public let memberId: String
    public let name: String
    public let nickname: String
    public let part: UMCPartType
    /// 상대가 보낸 파트 문자열 중 **우리가 못 읽은 값**. 읽혔으면 `nil`.
    ///
    /// 교환은 크로스 플랫폼이라 상대(안드로이드 포함)가 우리가 모르는 파트를 보낼 수 있다.
    /// 그때 ``part`` 는 관례대로 `.admin` 으로 떨어지는데, 앱 안에서 `.admin` 은
    /// **「파트 없는 운영진」이라는 진짜 역할**이라 상대를 운영진으로 잘못 표시하게 된다.
    /// 원본을 함께 실어 화면은 서버가 준 값을 그대로 보여주고, 저장소에도 원본이 남아
    /// 나중에 파싱 규칙이 늘면 되살아난다 (절대규칙 #2 — 서버 값은 String 유지).
    public let partRaw: String?
    public let generation: String
    public let university: String
    public let email: String?
    public let github: String?
    public let linkedIn: String?
    public let blog: String?
    public let avatarURL: String?

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
        linkedIn: String?,
        blog: String?,
        avatarURL: String?,
        partRaw: String? = nil
    ) {
        self.partRaw = partRaw
        self.memberId = memberId
        self.name = name
        self.nickname = nickname
        self.part = part
        self.generation = generation
        self.university = university
        self.email = email
        self.github = github
        self.linkedIn = linkedIn
        self.blog = blog
        self.avatarURL = avatarURL
    }

    // MARK: - Computed Property

    /// 화면에 쓰는 파트 이름. 못 읽은 값이면 원본을 그대로 보여준다 — 틀린 이름(운영진)보다
    /// 낯선 이름이 낫다.
    public var partDisplayName: String {
        partRaw ?? part.name
    }

    /// 전송·저장에 싣는 파트 문자열. 원본을 받았으면 원본을 그대로 되돌려 보낸다 —
    /// 우리가 못 읽었다는 이유로 남의 값을 `ADMIN` 으로 바꿔 퍼뜨리면 안 된다.
    public var partAPIValue: String {
        partRaw ?? part.apiValue
    }

    /// 명함 프로필 딥링크.
    public var cardLink: CardLink {
        CardLink(memberId: memberId)
    }

    /// QR에 싣는 문자열. MP-F02 뒷면과 MP-F04가 반드시 같은 값을 쓴다.
    public var qrPayload: String {
        cardLink.urlString
    }
}
