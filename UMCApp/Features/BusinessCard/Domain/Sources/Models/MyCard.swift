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

    /// 명함 딥링크 문자열 — **만료가 없는 정체용 값이다.**
    ///
    /// 실제로 QR 에 굽는 값은 여기에 만료를 붙인 ``GenerateCardQRUseCase`` 의 결과다 (#1226).
    /// 근거리 교환 페이로드·명함첩 저장값처럼 시간이 지나도 상하면 안 되는 자리는 이 값을 쓴다.
    public var qrPayload: String {
        cardLink.urlString
    }

    // MARK: - Function

    /// 명함으로 쓸 수 있는 최소 조건을 확인한다.
    ///
    /// 기수가 비었다는 건 서버가 `roles`·`challengerRecords` 를 주지 않았거나, v1 교환
    /// 페이로드처럼 정체성 필드가 아예 없다는 뜻이다. 예전에는 그 자리를 `.admin`·`"0"`
    /// 으로 메워 「운영진 · 0기」 명함이 **에러 없이** 만들어지고 명함첩에 그대로
    /// 저장됐다 (#1223). 조회·저장 양쪽이 이 한 규칙을 부른다.
    ///
    /// 파트는 검사하지 않는다 — 파트 없는 `.admin` 은 진짜 운영진의 정상 상태라 그것만으로는
    /// 「서버가 아무것도 안 줬다」와 구분되지 않는다. 그 신호는 기수 쪽에만 남는다.
    public func validate() throws {
        guard !generation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.domain(.custom(message: "명함 정보를 불러오지 못했어요."))
        }
    }
}
