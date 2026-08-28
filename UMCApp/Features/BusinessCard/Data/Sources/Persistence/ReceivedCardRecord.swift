//
//  ReceivedCardRecord.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import SwiftData

/// 받은 명함 로컬 저장 모델 (SwiftData + CloudKit Sync — 명함첩이 기기 간 동기화된다).
///
/// - Note: CloudKit 호환 제약 — 전 필드 기본값 필수·`@Attribute(.unique)` 금지 (Home
///   `GenerationMappingRecord` 선례). 중복은 Repository가 memberId 기준으로 정리한다.
/// - Note: 서버 응답이 아닌 로컬 영속 모델이지만 `generation`은 도메인 그대로
///   String 보존 (경계 변환 없음). `exchangedAt`은 로컬 생성 값이라 본래 타입.
/// - Note: `partRaw`에는 **서버·상대가 준 문자열을 그대로** 담는다. 우리가 못 읽는
///   값이어도 `ADMIN`으로 눌러 저장하지 않는다 — 그러면 원본이 영영 사라진다.
/// - Note: 계정 격리는 `ownerMemberId` 열이 책임진다. CloudKit 동기화 축은 Apple ID 라
///   UMC 계정과 무관해서, 같은 Apple ID 로 두 계정을 쓰면 한 스토어에 섞여 내려온다.
@Model
public final class ReceivedCardRecord {

    // MARK: - Property

    /// 이 명함을 받은 **내 계정**의 memberId — 명함첩 격리 키.
    ///
    /// 저장소의 모든 조회·저장·삭제가 이 값으로 갈린다. 한 기기에서 계정을 바꿔도
    /// 이전 사용자의 명함(이름·학교·이메일·외부 링크)이 보이지 않게 하는 유일한 장치다.
    ///
    /// - Note: 기본값 `""` 은 CloudKit 제약(전 필드 기본값 필수)이자 SwiftData 경량
    ///   마이그레이션 경로다. 소유자를 모르는 구버전 레코드는 `""` 로 채워져 **어느
    ///   계정에도 잡히지 않는다** — 남의 명함을 보여주느니 안 보이는 쪽이 맞다.
    public var ownerMemberId: String = ""

    /// 교환 페이로드 cardID (upsert 부차 키)
    public var cardID: String = ""
    /// 상대 memberId (upsert 1차 키 — 같은 사람 재교환 시 갱신)
    public var memberId: String = ""
    public var name: String = ""
    public var nickname: String = ""
    /// `UMCPartType.apiValue` 문자열
    public var partRaw: String = ""
    public var generation: String = ""
    public var university: String = ""
    public var email: String?
    public var github: String?
    public var linkedIn: String?
    public var blog: String?
    public var avatarURL: String?
    public var exchangedAt: Date = Date()
    public var exchangeContext: String?
    /// `ExchangeMethod.rawValue`. 빈 문자열은 방식 기록 이전(#1227)에 저장된 행이다 —
    /// 옵셔널 대신 기본값을 둬야 CloudKit 이 받는다.
    public var exchangeMethodRaw: String = ""
    public var updatedAt: Date = Date()

    // MARK: - Init

    public init(
        ownerMemberId: String,
        cardID: String,
        memberId: String,
        name: String,
        nickname: String,
        partRaw: String,
        generation: String,
        university: String,
        email: String?,
        github: String?,
        linkedIn: String?,
        blog: String?,
        avatarURL: String?,
        exchangedAt: Date,
        exchangeContext: String?,
        exchangeMethodRaw: String = "",
        updatedAt: Date = Date()
    ) {
        self.ownerMemberId = ownerMemberId
        self.cardID = cardID
        self.memberId = memberId
        self.name = name
        self.nickname = nickname
        self.partRaw = partRaw
        self.generation = generation
        self.university = university
        self.email = email
        self.github = github
        self.linkedIn = linkedIn
        self.blog = blog
        self.avatarURL = avatarURL
        self.exchangedAt = exchangedAt
        self.exchangeContext = exchangeContext
        self.exchangeMethodRaw = exchangeMethodRaw
        self.updatedAt = updatedAt
    }
}
