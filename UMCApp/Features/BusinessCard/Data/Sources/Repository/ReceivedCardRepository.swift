//
//  ReceivedCardRepository.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import SwiftData
import UMCFoundation
import BusinessCardDomain

/// SwiftData 기반 명함첩 저장소 (MP-F05).
///
/// 서버 명함 API 부재 확정(2026-08-15 조사)으로 로컬 전용. 서버가 생기면 이 구현체만
/// 교체한다. CloudKit 제약상 unique 불가 → memberId 기준 fetch 후 수동 upsert
/// (Home `ChallengerGenRepository` 선례).
///
/// **모든 `modelContext` 접근은 메인 액터에서 한다.** 주입되는 것은 앱의 `mainContext`
/// (`UMCAppApp.makeModelContainer` → `DIContainer.configured(modelContext:)`)인데,
/// 이 타입의 메서드는 액터 격리가 없어 호출부가 `await` 하는 순간 백그라운드 실행자로
/// 넘어간다. 메인 큐에 묶인 Core Data 컨텍스트를 다른 큐에서 만지는 셈이라
/// **간헐적으로 멈춘다** — 실기기에서 명함첩 삭제가 무한 로딩으로 걸린 적이 있다
/// (재현은 못 했다). `MainActor.run` 으로 실행 위치를 컨텍스트가 있는 곳에 맞춘다.
public final class ReceivedCardRepository: ReceivedCardRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let modelContext: ModelContext

    // MARK: - Init

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Function

    /// 교환 시각 내림차순 전체 조회. CloudKit 동기화 중복은 `identityKey` 기준 최신만 남긴다.
    public func fetchAll() async throws -> [ReceivedCard] {
        try await MainActor.run { try dedupedRecords().map { $0.toDomain() } }
    }

    /// 인메모리 필터를 쓰는 이유: `#Predicate`로 걸러내면 CloudKit 중복 dedup이 술어
    /// 통과분에만 적용돼 `fetchAll()`과 결과 규칙이 갈린다(같은 memberId 중복 행 노출).
    /// 명함첩은 개인 수집 규모(수백 건)라 전량 fetch 비용이 dedup 일관성보다 싸다.
    /// 검색 대상에 nickname을 포함한다 — 명함첩은 닉네임으로 기억되는 경우가 많다.
    public func search(query: String) async throws -> [ReceivedCard] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return try await fetchAll() }
        return try await MainActor.run {
            try dedupedRecords()
                .filter {
                    $0.name.localizedStandardContains(needle)
                        || $0.nickname.localizedStandardContains(needle)
                        || $0.partRaw.localizedStandardContains(needle)
                        || $0.university.localizedStandardContains(needle)
                }
                .map { $0.toDomain() }
        }
    }

    /// memberId 일치 레코드가 있으면 최신 명함으로 갱신, 없으면 삽입.
    ///
    /// 1차 키는 **memberId**(cardLink `umc://card/{memberId}` 파싱값), 부차 키는 cardID다.
    /// cardLink가 페이로드에서 정체성을 나르는 유일한 값이므로 그 파싱값이 정본이다.
    public func save(_ card: ReceivedCard) async throws {
        try await MainActor.run {
            let records = try fetchRecords()
            if let existing = records.first(where: {
                !card.profile.memberId.isEmpty && $0.memberId == card.profile.memberId
            }) ?? records.first(where: { $0.cardID == card.id }) {
                existing.apply(card)
            } else {
                modelContext.insert(ReceivedCardRecord(card))
            }
            try modelContext.save()
        }
    }

    public func delete(id: String) async throws {
        try await MainActor.run {
            for record in try fetchRecords() where record.cardID == id {
                modelContext.delete(record)
            }
            try modelContext.save()
        }
    }

    public func count() async throws -> Int {
        try await MainActor.run { try dedupedRecords().count }
    }

    // MARK: - Private Function

    private func fetchRecords() throws -> [ReceivedCardRecord] {
        let descriptor = FetchDescriptor<ReceivedCardRecord>(
            sortBy: [SortDescriptor(\.exchangedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// CloudKit 동기화가 만들 수 있는 중복을 걸러낸다.
    /// `fetchRecords()`가 교환 시각 내림차순이라 살아남는 것은 가장 최근 교환분이다.
    private func dedupedRecords() throws -> [ReceivedCardRecord] {
        var seenKeys = Set<String>()
        return try fetchRecords().filter { seenKeys.insert($0.identityKey).inserted }
    }
}

// MARK: - Identity

private extension ReceivedCardRecord {

    /// 중복 판정 키. `memberId`(cardLink 파싱값)가 정본이고, **없을 때만** cardID로 대체한다.
    ///
    /// 키를 둘로 가르는 이유: v1 페이로드(cardLink="")나 파싱 불가한 cardLink를 받으면
    /// `MyCard(payload:)`가 memberId를 빈 문자열로 복원한다. 이때
    /// - 빈 문자열을 하나의 키로 뭉치면 **서로 다른 사람이 한 명으로 사라진다**(데이터 손실)
    /// - 그렇다고 전부 통과시키면 CloudKit 동기화 중복이 그대로 쌓인다
    ///
    /// cardID는 교환마다 새 UUID라 정체성이 없는 상대와 **재교환**하면 여전히 새 행이 생긴다.
    /// 그건 신원 정보가 없는 이상 원리적으로 막을 수 없다 — 여기서 막는 것은 동기화 중복이다.
    var identityKey: String {
        memberId.isEmpty ? "card:\(cardID)" : "member:\(memberId)"
    }
}

// MARK: - Mapping

private extension ReceivedCardRecord {

    convenience init(_ card: ReceivedCard) {
        self.init(
            cardID: card.id,
            memberId: card.profile.memberId,
            name: card.profile.name,
            nickname: card.profile.nickname,
            partRaw: card.profile.part.apiValue,
            generation: card.profile.generation,
            university: card.profile.university,
            email: card.profile.email,
            github: card.profile.github,
            linkedIn: card.profile.linkedIn,
            blog: card.profile.blog,
            avatarURL: card.profile.avatarURL,
            exchangedAt: card.exchangedAt,
            exchangeContext: card.exchangeContext,
            isConnected: card.isConnected
        )
    }

    func apply(_ card: ReceivedCard) {
        cardID = card.id
        memberId = card.profile.memberId
        name = card.profile.name
        nickname = card.profile.nickname
        partRaw = card.profile.part.apiValue
        generation = card.profile.generation
        university = card.profile.university
        email = card.profile.email
        github = card.profile.github
        linkedIn = card.profile.linkedIn
        blog = card.profile.blog
        avatarURL = card.profile.avatarURL
        exchangedAt = card.exchangedAt
        exchangeContext = card.exchangeContext
        isConnected = card.isConnected
        updatedAt = .now
    }

    func toDomain() -> ReceivedCard {
        ReceivedCard(
            id: cardID,
            profile: MyCard(
                memberId: memberId,
                name: name,
                nickname: nickname,
                part: UMCPartType(apiValue: partRaw) ?? .admin,
                generation: generation,
                university: university,
                email: email,
                github: github,
                linkedIn: linkedIn,
                blog: blog,
                avatarURL: avatarURL
            ),
            exchangedAt: exchangedAt,
            exchangeContext: exchangeContext,
            isConnected: isConnected
        )
    }
}
