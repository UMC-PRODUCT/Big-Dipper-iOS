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
/// **모든 조회·저장·삭제는 현재 로그인 계정(`ownerMemberId`)으로 스코프된다.** 한 기기에서
/// 계정을 바꾸면 이전 사용자의 명함이 그대로 보이던 문제(#1217)를 여기서 막는다. 소유자를
/// 호출부가 넘기게 하지 않고 저장소가 직접 읽는 이유는, 넘기게 하면 언젠가 빼먹기 때문이다.
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
    private let defaults: UserDefaults

    // MARK: - Init

    /// - Parameter defaults: 현재 로그인 계정을 읽을 저장소. 테스트는 격리된 suite를 넣는다.
    public init(modelContext: ModelContext, defaults: UserDefaults = .standard) {
        self.modelContext = modelContext
        self.defaults = defaults
    }

    // MARK: - Computed Property

    /// 지금 로그인한 계정의 memberId. `nil`이면 로그인 세션이 없다.
    ///
    /// `init`에서 붙잡지 않고 호출마다 다시 읽는다 — `DIContainer.resolve`가 인스턴스를
    /// 캐싱하므로 붙잡으면 계정을 바꾼 뒤에도 옛 소유자로 조회·저장하게 된다.
    private var currentOwnerMemberId: String? {
        AppStorageKey.memberIdString(in: defaults)
    }

    // MARK: - Function

    /// 교환 시각 내림차순 전체 조회. CloudKit 동기화 중복은 `identityKey` 기준 최신만 남긴다.
    ///
    /// 로그인 세션이 없으면 빈 목록이다 — 소유자를 모르는 상태에서 무엇이든 보여주면
    /// 그게 곧 남의 명함첩이다.
    public func fetchAll() async throws -> [ReceivedCard] {
        guard let owner = currentOwnerMemberId else { return [] }
        return try await MainActor.run { try dedupedRecords(owner: owner).map { $0.toDomain() } }
    }

    /// 검색어 필터를 인메모리로 두는 이유: `#Predicate`로 걸러내면 CloudKit 중복 dedup이
    /// 술어 통과분에만 적용돼 `fetchAll()`과 결과 규칙이 갈린다(같은 memberId 중복 행 노출).
    /// 명함첩은 개인 수집 규모(수백 건)라 전량 fetch 비용이 dedup 일관성보다 싸다.
    /// 소유자 술어는 이 이유에 걸리지 않는다 — 계정 경계는 dedup 범위 자체라 술어로 좁혀도
    /// 규칙이 갈리지 않고, 무엇보다 남의 명함을 메모리에 올리지 않는 쪽이 맞다.
    /// 검색 대상에 nickname을 포함한다 — 명함첩은 닉네임으로 기억되는 경우가 많다.
    public func search(query: String) async throws -> [ReceivedCard] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return try await fetchAll() }
        guard let owner = currentOwnerMemberId else { return [] }
        return try await MainActor.run {
            try dedupedRecords(owner: owner)
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
        let owner = try requireOwner()
        try await MainActor.run {
            let records = try fetchRecords(owner: owner)
            if let existing = records.first(where: {
                !card.profile.memberId.isEmpty && $0.memberId == card.profile.memberId
            }) ?? records.first(where: { $0.cardID == card.id }) {
                existing.apply(card)
            } else {
                modelContext.insert(ReceivedCardRecord(card, ownerMemberId: owner))
            }
            try modelContext.save()
        }
    }

    public func delete(id: String) async throws {
        let owner = try requireOwner()
        try await MainActor.run {
            for record in try fetchRecords(owner: owner) where record.cardID == id {
                modelContext.delete(record)
            }
            try modelContext.save()
        }
    }

    public func count() async throws -> Int {
        guard let owner = currentOwnerMemberId else { return 0 }
        return try await MainActor.run { try dedupedRecords(owner: owner).count }
    }

    /// 현재 계정의 명함을 전부 지운다 (회원 탈퇴).
    ///
    /// 로그아웃에서는 부르지 않는다 — 명함첩은 서버 사본이 없어서, 잠깐 로그아웃했다
    /// 돌아온 사용자의 명함까지 날아간다. 로그아웃 격리는 소유자 술어가 이미 해낸다.
    public func deleteAll() async throws {
        let owner = try requireOwner()
        try await MainActor.run {
            for record in try fetchRecords(owner: owner) {
                modelContext.delete(record)
            }
            try modelContext.save()
        }
    }

    // MARK: - Private Function

    /// 쓰기 경로의 소유자. 없으면 조용히 넘어가지 않는다 — 소유자 없이 저장하면 그 명함은
    /// 어느 계정에도 안 잡히는 유령이 된다. 화면 안에서 사용자가 되돌릴 수 없는 실패라
    /// 전역 재로그인 유도로 이어지는 `AuthError.notLoggedIn`을 던진다.
    private func requireOwner() throws -> String {
        guard let owner = currentOwnerMemberId else { throw AuthError.notLoggedIn }
        return owner
    }

    private func fetchRecords(owner: String) throws -> [ReceivedCardRecord] {
        let descriptor = FetchDescriptor<ReceivedCardRecord>(
            predicate: #Predicate { $0.ownerMemberId == owner },
            sortBy: [SortDescriptor(\.exchangedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// CloudKit 동기화가 만들 수 있는 중복을 걸러낸다.
    /// `fetchRecords(owner:)`가 교환 시각 내림차순이라 살아남는 것은 가장 최근 교환분이다.
    private func dedupedRecords(owner: String) throws -> [ReceivedCardRecord] {
        var seenKeys = Set<String>()
        return try fetchRecords(owner: owner).filter { seenKeys.insert($0.identityKey).inserted }
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

    convenience init(_ card: ReceivedCard, ownerMemberId: String) {
        self.init(
            ownerMemberId: ownerMemberId,
            cardID: card.id,
            memberId: card.profile.memberId,
            name: card.profile.name,
            nickname: card.profile.nickname,
            partRaw: card.profile.partAPIValue,
            generation: card.profile.generation,
            university: card.profile.university,
            email: card.profile.email,
            github: card.profile.github,
            linkedIn: card.profile.linkedIn,
            blog: card.profile.blog,
            avatarURL: card.profile.avatarURL,
            exchangedAt: card.exchangedAt,
            exchangeContext: card.exchangeContext
        )
    }

    func apply(_ card: ReceivedCard) {
        cardID = card.id
        memberId = card.profile.memberId
        name = card.profile.name
        nickname = card.profile.nickname
        partRaw = card.profile.partAPIValue
        generation = card.profile.generation
        university = card.profile.university
        email = card.profile.email
        github = card.profile.github
        linkedIn = card.profile.linkedIn
        blog = card.profile.blog
        avatarURL = card.profile.avatarURL
        exchangedAt = card.exchangedAt
        exchangeContext = card.exchangeContext
        updatedAt = .now
    }

    /// 저장된 문자열이 우리가 아는 파트가 아니면 원본을 되살린다 — 저장 때 원본을 넣었으므로
    /// 파싱 규칙이 나중에 늘면 재설치 없이 제대로 읽히기 시작한다.
    func toDomain() -> ReceivedCard {
        let parsedPart = UMCPartType(apiValue: partRaw)
        return ReceivedCard(
            id: cardID,
            profile: MyCard(
                memberId: memberId,
                name: name,
                nickname: nickname,
                part: parsedPart ?? .admin,
                generation: generation,
                university: university,
                email: email,
                github: github,
                linkedIn: linkedIn,
                blog: blog,
                avatarURL: avatarURL,
                partRaw: (parsedPart == nil && !partRaw.isEmpty) ? partRaw : nil
            ),
            exchangedAt: exchangedAt,
            exchangeContext: exchangeContext
        )
    }
}
