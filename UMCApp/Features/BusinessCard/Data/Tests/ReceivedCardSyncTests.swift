//
//  ReceivedCardSyncTests.swift
//  BusinessCardDataTests
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import SwiftData
import Testing
import UMCFoundation
import BusinessCardDomain
@testable import BusinessCardData

/// 전량 재조정의 위험은 **지우면 안 되는 것을 지우는 것** 하나로 모인다. 아래는 그
/// 경계를 전부 고정한다 — 미푸시 행·스캔 중 생긴 행·로컬 메모·아직 못 올린 익명 행.
@MainActor
@Suite("ReceivedCardRepository.sync — 재조정 경계와 push 규칙")
struct ReceivedCardSyncTests {

    // MARK: - Stub

    private final class StubRemote: ReceivedCardRemoteSyncing, @unchecked Sendable {

        var pages: [Result<CardExchangePageDTO, Error>] = [.success(CardExchangePageDTO(
            content: [], nextCursor: nil, hasNext: false
        ))]
        var createError: Error?
        /// 페이지를 내주기 **직전** 실행된다. 스캔 도중 새 행이 생기는 레이스를 만든다.
        var beforeFetch: (@Sendable (Int) async -> Void)?

        private(set) var fetchedCursors: [String?] = []
        private(set) var pushed: [PendingCardExchange] = []
        private(set) var deletedMemberIds: [String] = []

        func fetchExchanges(cursor: String?, size: Int) async throws -> CardExchangePageDTO {
            let index = fetchedCursors.count
            fetchedCursors.append(cursor)
            await beforeFetch?(index)
            guard index < pages.count else { throw StubError.exhausted }
            return try pages[index].get()
        }

        func createExchange(_ exchange: PendingCardExchange) async throws {
            if let createError { throw createError }
            pushed.append(exchange)
        }

        func deleteExchange(cardMemberId: String) async throws {
            deletedMemberIds.append(cardMemberId)
        }
    }

    private enum StubError: Error { case exhausted, offline }

    // MARK: - Property

    private static let owner = "100"

    /// 컨테이너를 함께 붙잡지 않으면 인메모리 스토어가 먼저 해제돼 트랩한다.
    private let container: ModelContainer
    private let defaults: UserDefaults
    private let remote = StubRemote()
    private let repository: ReceivedCardRepository

    // MARK: - Init

    init() throws {
        container = try ModelContainer(
            for: ReceivedCardRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let suiteName = "test.businessCard.sync.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(Self.owner, forKey: AppStorageKey.memberId)
        repository = ReceivedCardRepository(
            modelContext: container.mainContext,
            defaults: defaults,
            remote: remote
        )
    }

    // MARK: - Test

    @Test("서버 집합에 없고 이전에 서버에서 확인된 행은 지워진다")
    func removesRowMissingFromServer() async throws {
        insertRecord(memberId: "7", serverSyncedAt: Date().addingTimeInterval(-60))

        try await repository.sync()

        #expect(try await repository.fetchAll().isEmpty)
    }

    /// 근거리 교환은 인터넷 없이 성립한다. 아직 못 올렸다는 이유로 지우면 눈앞에서
    /// 교환한 명함이 사라진다.
    @Test("아직 서버에 못 올린 행(serverSyncedAt == nil)은 지우지 않는다")
    func keepsUnpushedRow() async throws {
        insertRecord(memberId: "8", serverSyncedAt: nil)

        try await repository.sync()

        #expect(try await repository.fetchAll().count == 1)
        #expect(remote.pushed.map(\.cardMemberId) == ["8"])
    }

    /// 스캔 도중 생긴 행은 커서 위쪽이라 이번 페이지들에 잡히지 않는다. 시작 시각
    /// 비교가 없으면 「서버에 없다」는 이유로 방금 받은 명함을 지운다.
    @Test("스캔 시작 이후에 확인된 행은 서버 집합에 없어도 살아남는다")
    func keepsRowConfirmedAfterScanStart() async throws {
        insertRecord(memberId: "7", serverSyncedAt: Date().addingTimeInterval(-60))
        remote.pages = [.success(CardExchangePageDTO(
            content: [makeItem(memberId: "7")], nextCursor: nil, hasNext: false
        ))]
        let context = container.mainContext
        remote.beforeFetch = { @Sendable index in
            guard index == 0 else { return }
            await MainActor.run {
                context.insert(Self.makeRecord(memberId: "999", serverSyncedAt: Date()))
                try? context.save()
            }
        }

        try await repository.sync()

        let memberIds = try await repository.fetchAll().map(\.profile.memberId)
        #expect(Set(memberIds) == ["7", "999"])
    }

    /// 부분 반영은 「지워지지 않은 채 사라진 명함」을 만든다. 전부 버퍼링한 뒤 한 번에
    /// 적용해 애초에 불가능한 구조인지 확인한다.
    @Test("2페이지째가 실패하면 1페이지 결과도 반영되지 않는다")
    func appliesNothingWhenLaterPageFails() async throws {
        insertRecord(memberId: "7", serverSyncedAt: Date().addingTimeInterval(-60))
        remote.pages = [
            .success(CardExchangePageDTO(
                content: [makeItem(memberId: "42")], nextCursor: "42", hasNext: true
            )),
            .failure(StubError.offline)
        ]

        await #expect(throws: StubError.self) { try await repository.sync() }

        let memberIds = try await repository.fetchAll().map(\.profile.memberId)
        #expect(memberIds == ["7"], "1페이지의 42번이 들어갔거나 7번이 지워졌다")
    }

    /// 상대가 나를 명함첩에서 지우면 서버가 이메일을 내리지 않는다. 로컬 캐시로 폴백하면
    /// 지워진 이메일이 계속 보인다 — 프라이버시 사고다.
    @Test("서버가 email을 null로 주면 로컬 이메일이 지워진다")
    func clearsEmailWhenServerOmitsIt() async throws {
        insertRecord(memberId: "7", email: "before@umc.dev", serverSyncedAt: nil)
        remote.pages = [.success(CardExchangePageDTO(
            content: [makeItem(memberId: "7", email: nil, isMutual: false)],
            nextCursor: nil, hasNext: false
        ))]

        try await repository.sync()

        #expect(try await repository.fetchAll().first?.profile.email == nil)
    }

    /// 교환 맥락 메모는 서버가 모르는 로컬 값이다. 재조정이 덮으면 사용자가 적은 것이 사라진다.
    @Test("로컬 교환 메모는 재조정이 덮어쓰지 않는다")
    func keepsLocalExchangeContext() async throws {
        insertRecord(memberId: "7", exchangeContext: "OT에서 교환", serverSyncedAt: nil)
        remote.pages = [.success(CardExchangePageDTO(
            content: [makeItem(memberId: "7")], nextCursor: nil, hasNext: false
        ))]

        try await repository.sync()

        #expect(try await repository.fetchAll().first?.exchangeContext == "OT에서 교환")
    }

    /// 상대 memberId를 모르는 행(오프라인 QR 페이로드·구버전 교환)은 서버에 올릴 값이
    /// 없다. 올릴 수 없다는 이유로 지우지도 않는다.
    @Test("memberId가 없는 행은 push하지 않고 지우지도 않는다")
    func neverPushesAnonymousRow() async throws {
        insertRecord(memberId: "", serverSyncedAt: nil)

        try await repository.sync()

        #expect(remote.pushed.isEmpty)
        #expect(try await repository.fetchAll().count == 1)
    }

    /// 서버에 명함 API가 배포되기 전까지 릴리스 빌드가 지나는 경로다. 지금 동작과
    /// 완전히 같아야 한다.
    @Test("remote가 없으면 sync는 아무 일도 하지 않는다")
    func noOpsWithoutRemote() async throws {
        let local = ReceivedCardRepository(
            modelContext: container.mainContext, defaults: defaults, remote: nil
        )
        insertRecord(memberId: "7", serverSyncedAt: Date().addingTimeInterval(-60))

        try await local.sync()

        #expect(try await local.fetchAll().count == 1)
    }

    /// 로컬만 지우면 다음 재조정이 서버 집합에서 그 명함을 되살린다 — #1218을 서버
    /// 축에서 그대로 재현하는 것이다.
    @Test("삭제는 서버에 먼저 전파된다")
    func propagatesDeleteToServer() async throws {
        insertRecord(memberId: "7", serverSyncedAt: Date().addingTimeInterval(-60))

        try await repository.delete(id: "CARD-7")

        #expect(remote.deletedMemberIds == ["7"])
        #expect(try await repository.fetchAll().isEmpty)
    }

    // MARK: - Function

    private func insertRecord(
        memberId: String,
        email: String? = nil,
        exchangeContext: String? = nil,
        serverSyncedAt: Date?
    ) {
        container.mainContext.insert(Self.makeRecord(
            memberId: memberId,
            email: email,
            exchangeContext: exchangeContext,
            serverSyncedAt: serverSyncedAt
        ))
        try? container.mainContext.save()
    }

    private static func makeRecord(
        memberId: String,
        email: String? = nil,
        exchangeContext: String? = nil,
        serverSyncedAt: Date?
    ) -> ReceivedCardRecord {
        ReceivedCardRecord(
            ownerMemberId: owner,
            cardID: "CARD-\(memberId)",
            memberId: memberId,
            name: "상대\(memberId)",
            nickname: "닉\(memberId)",
            partRaw: "DESIGN",
            generation: "11",
            university: "중앙대학교",
            email: email,
            github: nil,
            linkedIn: nil,
            blog: nil,
            avatarURL: nil,
            exchangedAt: Date(),
            exchangeContext: exchangeContext,
            exchangeMethodRaw: ExchangeMethod.nearby.rawValue,
            serverSyncedAt: serverSyncedAt
        )
    }

    private func makeItem(
        memberId: String,
        email: String? = "after@umc.dev",
        isMutual: Bool = true
    ) -> CardExchangeItemDTO {
        CardExchangeItemDTO(
            cardMemberId: memberId,
            name: "상대\(memberId)",
            nickname: "닉\(memberId)",
            part: "DESIGN",
            generation: "11",
            schoolName: "중앙대학교",
            email: email,
            source: "QR",
            exchangedAt: ServerDateTimeConverter.toUTCDateTimeString(Date()),
            isMutual: isMutual
        )
    }
}
