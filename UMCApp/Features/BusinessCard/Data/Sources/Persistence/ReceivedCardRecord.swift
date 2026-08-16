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
///   String 보존 (경계 변환 없음). `exchangedAt`/`isConnected`는 로컬 생성 값이라 본래 타입.
@Model
public final class ReceivedCardRecord {

    // MARK: - Property

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
    public var blog: String?
    public var avatarURL: String?
    public var exchangedAt: Date = Date()
    public var exchangeContext: String?
    public var isConnected: Bool = false
    public var updatedAt: Date = Date()

    // MARK: - Init

    public init(
        cardID: String,
        memberId: String,
        name: String,
        nickname: String,
        partRaw: String,
        generation: String,
        university: String,
        email: String?,
        github: String?,
        blog: String?,
        avatarURL: String?,
        exchangedAt: Date,
        exchangeContext: String?,
        isConnected: Bool,
        updatedAt: Date = Date()
    ) {
        self.cardID = cardID
        self.memberId = memberId
        self.name = name
        self.nickname = nickname
        self.partRaw = partRaw
        self.generation = generation
        self.university = university
        self.email = email
        self.github = github
        self.blog = blog
        self.avatarURL = avatarURL
        self.exchangedAt = exchangedAt
        self.exchangeContext = exchangeContext
        self.isConnected = isConnected
        self.updatedAt = updatedAt
    }
}
