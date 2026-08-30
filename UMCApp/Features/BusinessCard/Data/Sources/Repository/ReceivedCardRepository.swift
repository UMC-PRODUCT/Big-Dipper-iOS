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

// MARK: - Constants

private enum Constants {
    /// 서버가 허용하는 최대 페이지 크기. 명함첩은 개인 수집 규모라 항상 최대로 받아
    /// 왕복을 줄인다.
    static let pageSize = 100
    /// 페이지 반복 상한(= 5,000건). 서버 버그로 커서가 끝나지 않을 때 앱이 그 무한 루프를
    /// 흡수하지 않는다.
    static let maxPages = 50
}

/// 동기화가 서버 응답 때문에 끝나지 못한 경우.
enum CardSyncError: Error, LocalizedError {

    /// 페이지 상한을 넘었거나 커서가 전진하지 않았다.
    case pageLimitExceeded

    var errorDescription: String? {
        "명함첩을 모두 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
    }
}

/// SwiftData 기반 명함첩 저장소 (MP-F05).
///
/// 로컬이 캐시, 서버 집합이 정본이다 — 단 ``remote`` 가 `nil` 이면(서버에 명함 API 가
/// 배포되기 전까지의 릴리스 구성) 지금까지처럼 완전한 로컬 전용으로 돈다.
/// CloudKit 제약상 unique 불가 → 정체성 키로 fetch 후 수동 upsert
/// (Home `ChallengerGenRepository` 선례).
///
/// **저장·중복 제거·삭제는 모두 `identityKey` 한 규칙을 쓴다.** 셋이 갈리면 목록에
/// 보이지 않는 행이 남아 삭제한 명함이 되살아난다 (#1218).
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
    private let remote: (any ReceivedCardRemoteSyncing)?

    // MARK: - Init

    /// - Parameter defaults: 현재 로그인 계정을 읽을 저장소. 테스트는 격리된 suite를 넣는다.
    /// - Parameter remote: 서버 명함첩 경계. `nil`이면 지금까지처럼 **로컬 전용**으로 돈다
    ///   — 서버에 명함 API가 배포되기 전까지 릴리스 빌드가 이 경로다.
    public init(
        modelContext: ModelContext,
        defaults: UserDefaults = .standard,
        remote: (any ReceivedCardRemoteSyncing)? = nil
    ) {
        self.modelContext = modelContext
        self.defaults = defaults
        self.remote = remote
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

    /// 같은 정체성의 레코드가 있으면 최신 명함으로 갱신, 없으면 삽입.
    public func save(_ card: ReceivedCard) async throws {
        let owner = try requireOwner()
        try await MainActor.run {
            let key = card.identityKey
            if let existing = try fetchRecords(owner: owner).first(where: {
                $0.identityKey == key
            }) {
                existing.apply(card)
            } else {
                modelContext.insert(ReceivedCardRecord(card, ownerMemberId: owner))
            }
            try modelContext.save()
        }
        await pushIfPossible(card)
    }

    /// 목록에서 고른 명함을 지운다.
    ///
    /// `id`는 목록에 보인 **한 장**의 cardID지만, 지우는 단위는 그 명함의 정체성이다.
    /// cardID로만 지우면 같은 사람의 다른 cardID 행(재교환·다기기 CloudKit 동기화로
    /// 생긴다)이 남아 다음 진입에서 되살아난다 (#1218).
    ///
    /// 원격이 붙어 있으면 **서버를 먼저 지우고** 로컬을 지운다. 순서를 뒤집거나 실패를
    /// 삼키면 다음 재조정이 서버 집합에서 그 명함을 되살린다 — #1218을 서버 축에서 그대로
    /// 재현하는 것이다. 오프라인 삭제를 큐에 쌓지 않는 이유도 같다: 큐를 두면 모든 읽기
    /// 경로에서 「지우는 중」 행을 걸러야 하고, 그 필터는 반드시 어딘가에서 빠진다.
    ///
    /// - Important: 로컬이 아직 서버 확인을 못 받은 행(`serverSyncedAt == nil`)도 원격
    ///   삭제를 부른다. ``save(_:)`` 의 즉시 push 가 이미 성공했을 수 있고, 그 행을 로컬만
    ///   지우면 다음 pull 이 되살린다. **서버 DELETE 는 없는 행에도 성공해야 한다**(멱등).
    public func delete(id: String) async throws {
        let owner = try requireOwner()
        let found = try await MainActor.run { () -> DeleteTarget? in
            let records = try fetchRecords(owner: owner)
            guard let record = records.first(where: { $0.cardID == id }) else { return nil }
            return DeleteTarget(identityKey: record.identityKey, memberId: record.memberId)
        }
        guard let target = found else { return }

        if let remote, !target.memberId.isEmpty {
            try await remote.deleteExchange(cardMemberId: target.memberId)
        }

        try await MainActor.run {
            for record in try fetchRecords(owner: owner)
            where record.identityKey == target.identityKey {
                modelContext.delete(record)
            }
            try modelContext.save()
        }
    }

    public func count() async throws -> Int {
        guard let owner = currentOwnerMemberId else { return 0 }
        return try await MainActor.run { try dedupedRecords(owner: owner).count }
    }

    /// 서버 집합으로 로컬 캐시를 재조정한다. 원격이 없으면 아무 일도 하지 않는다.
    ///
    /// 절차는 push → 전량 pull → 단일 트랜잭션 적용 셋이다. **중간 페이지에서 실패하면
    /// 아무것도 반영하지 않는다** — 부분 반영을 금지하는 별도 로직을 두는 대신 전부
    /// 버퍼링한 뒤 한 번에 적용해 애초에 부분 반영이 불가능한 구조로 둔다.
    ///
    /// - Important: 네트워크 왕복은 `MainActor.run` **밖**에서 돈다. 액터 경계를 넘는 값은
    ///   전부 `Sendable` 값 타입이고, `ReceivedCardRecord`(`@Model`)는 절대 나가지 않는다.
    /// - Note: 중복 실행 방지 게이트를 두지 않는다. push는 서버 upsert라 멱등이고 pull은
    ///   읽기 전용이며 적용은 메인 액터에서 직렬화된다 — 낭비일 뿐 틀리지 않는다.
    public func sync() async throws {
        guard let remote else { return }
        let owner = try requireOwner()

        let pendings = try await MainActor.run { try pendingPushes(owner: owner) }
        for pending in pendings {
            // 행별 실패는 비치명이다. 다음 동기화가 다시 올린다 — 로컬 행 자체가 큐다.
            try? await remote.createExchange(pending)
        }

        let syncStartedAt = Date()
        var items: [CardExchangeItemDTO] = []
        var cursor: String?
        for _ in 0..<Constants.maxPages {
            let page = try await remote.fetchExchanges(
                cursor: cursor, size: Constants.pageSize
            )
            items.append(contentsOf: page.content)
            // 커서가 전진하지 않으면 같은 페이지를 영원히 받는다.
            guard page.hasNext, let next = page.nextCursor, !next.isEmpty, next != cursor else {
                try await MainActor.run {
                    try reconcile(items, owner: owner, syncStartedAt: syncStartedAt)
                }
                return
            }
            cursor = next
        }
        throw CardSyncError.pageLimitExceeded
    }

    /// 현재 계정의 명함을 전부 지운다 (회원 탈퇴).
    ///
    /// 로그아웃에서는 부르지 않는다 — 잠깐 로그아웃했다 돌아온 사용자의 명함까지 날아간다.
    /// 로그아웃 격리는 소유자 술어가 이미 해낸다.
    ///
    /// 원격은 부르지 않는다. 탈퇴는 서버가 회원 삭제와 함께 CASCADE 로 지운다.
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

    /// 방금 저장한 명함을 곧바로 서버에 올린다. 실패해도 던지지 않는다 — 다음 동기화가
    /// 다시 올린다. 근거리 교환은 인터넷 없이 성립하므로 오프라인은 예외가 아니라 정상
    /// 경로이고, 여기서 던지면 눈앞에서 교환한 사람을 잃는다.
    private func pushIfPossible(_ card: ReceivedCard) async {
        guard let remote, !card.profile.memberId.isEmpty else { return }
        try? await remote.createExchange(
            PendingCardExchange(
                cardMemberId: card.profile.memberId,
                source: card.exchangeMethod.serverSourceValue,
                exchangedAt: ServerDateTimeConverter.toUTCDateTimeString(card.exchangedAt)
            )
        )
    }

    /// 아직 서버에 없는 행. 상대 memberId 를 모르는 행(`anon:`)은 올릴 값이 없어 제외한다
    /// — 올릴 수 없다는 이유로 지우지도 않는다(`serverSyncedAt == nil` 이라 재조정 삭제
    /// 대상에서도 빠진다).
    @MainActor
    private func pendingPushes(owner: String) throws -> [PendingCardExchange] {
        try fetchRecords(owner: owner)
            .filter { $0.serverSyncedAt == nil && !$0.memberId.isEmpty }
            .map {
                PendingCardExchange(
                    cardMemberId: $0.memberId,
                    source: ExchangeMethod(storedValue: $0.exchangeMethodRaw).serverSourceValue,
                    exchangedAt: ServerDateTimeConverter.toUTCDateTimeString($0.exchangedAt)
                )
            }
    }

    /// 서버 집합을 로컬에 반영한다 — upsert·삭제·저장이 한 트랜잭션이다.
    ///
    /// 삭제 대상은 **세 조건을 모두** 만족하는 행뿐이다.
    /// 1. `serverSyncedAt != nil` — 서버에서 온 적이 있다(미푸시 행 면제).
    /// 2. `serverSyncedAt < syncStartedAt` — 이번 스캔 시작 이전에 확인됐다. 스캔 도중
    ///    생긴 행은 `id` 가 커서 위쪽이라 스캔에 안 잡히는데, 이 조건이 그 행을 살린다.
    /// 3. 서버 집합에 정체성 키가 없다.
    @MainActor
    private func reconcile(
        _ items: [CardExchangeItemDTO],
        owner: String,
        syncStartedAt: Date
    ) throws {
        let records = try fetchRecords(owner: owner)
        var recordsByKey: [String: [ReceivedCardRecord]] = [:]
        for record in records {
            recordsByKey[record.identityKey, default: []].append(record)
        }

        let syncedAt = Date()
        var serverKeys = Set<String>()
        for item in items where !item.cardMemberId.isEmpty {
            let key = cardIdentityKey(
                memberId: item.cardMemberId,
                name: item.name,
                nickname: item.nickname,
                university: item.schoolName,
                generation: item.generation
            )
            serverKeys.insert(key)
            // CloudKit 중복 행이 있으면 전부 갱신한다 — 한 행만 고치면 남은 행이 stale 한
            // 채로 dedup 순서에 따라 목록에 튀어나온다.
            if let existing = recordsByKey[key] {
                for record in existing {
                    item.applyServerFields(to: record, syncedAt: syncedAt)
                }
            } else {
                modelContext.insert(item.makeRecord(ownerMemberId: owner, syncedAt: syncedAt))
            }
        }

        for record in records {
            guard let confirmedAt = record.serverSyncedAt,
                  confirmedAt < syncStartedAt,
                  !serverKeys.contains(record.identityKey) else { continue }
            modelContext.delete(record)
        }
        try modelContext.save()
    }
}

/// 삭제 대상의 요약. `@Model` 인스턴스를 메인 액터 밖으로 내보내지 않으려고 값으로 꺼낸다.
private struct DeleteTarget: Sendable {
    let identityKey: String
    let memberId: String
}

// MARK: - Identity

/// 명함첩 정체성 키 — **저장(upsert)·중복 제거·삭제가 모두 이 한 규칙을 쓴다.**
///
/// 셋이 서로 다른 키를 쓰면 목록에 보이지 않는 행이 남아 삭제한 명함이 되살아난다(#1218).
///
/// `memberId`(cardLink `umc://card/{memberId}` 파싱값)가 정본이다 — 페이로드에서 정체성을
/// 나르는 유일한 값이다. **없을 때만** 명함 내용으로 대체한다. cardID는 대체 키가 될 수 없다:
/// 교환마다 새 UUID라(`MyCard.toExchangePayload(cardID:)`) 같은 사람과 다시 교환할 때마다
/// 새 행이 쌓이고, CloudKit 동기화 중복도 그대로 남는다.
///
/// - Note: 동명이인이 학교·기수·닉네임까지 같으면 한 장으로 합쳐진다. 신원 값이 없는 이상
///   이보다 정확할 수 없고, 무한 중복보다는 낫다. 명함 전용 서버 API가 생겨 memberId가
///   항상 실리면 이 대체 경로 자체가 사라진다.
private func cardIdentityKey(
    memberId: String,
    name: String,
    nickname: String,
    university: String,
    generation: String
) -> String {
    guard memberId.isEmpty else { return "member:\(memberId)" }
    return "anon:\(name)|\(nickname)|\(university)|\(generation)"
}

private extension ReceivedCardRecord {

    var identityKey: String {
        cardIdentityKey(
            memberId: memberId,
            name: name,
            nickname: nickname,
            university: university,
            generation: generation
        )
    }
}

private extension ReceivedCard {

    var identityKey: String {
        cardIdentityKey(
            memberId: profile.memberId,
            name: profile.name,
            nickname: profile.nickname,
            university: profile.university,
            generation: profile.generation
        )
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
            exchangeContext: card.exchangeContext,
            exchangeMethodRaw: card.exchangeMethod.rawValue
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
        exchangeMethodRaw = card.exchangeMethod.rawValue
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
            exchangeContext: exchangeContext,
            exchangeMethod: ExchangeMethod(storedValue: exchangeMethodRaw)
        )
    }
}
