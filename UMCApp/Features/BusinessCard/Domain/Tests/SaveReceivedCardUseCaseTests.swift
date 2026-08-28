//
//  SaveReceivedCardUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import CoreNearbyExchange
import UMCFoundation
@testable import BusinessCardDomain

@Suite("SaveReceivedCardUseCase — 페이로드 변환 후 저장 위임")
struct SaveReceivedCardUseCaseTests {

    private func makePayload() throws -> ExchangePayload {
        try ExchangePayload(
            cardID: "CARD-PEER", name: "상대", nickname: "상대닉", part: "DESIGN",
            generation: "11", university: "중앙대학교", email: nil, github: nil,
            linkedIn: nil, blog: nil, avatarURL: nil, cardLink: "umc://card/7"
        )
    }

    @Test("페이로드를 ReceivedCard로 변환해 저장하고 그 값을 반환한다")
    func convertsAndSaves() async throws {
        let repository = MockReceivedCardRepository()
        let sut = SaveReceivedCardUseCase(repository: repository)

        let saved = try await sut.execute(
            payload: try makePayload(),
            ownerMemberId: "42",
            exchangeContext: "OT에서 교환",
            exchangeMethod: .qrLink
        )

        #expect(saved?.id == "CARD-PEER")
        #expect(saved?.profile.memberId == "7")
        #expect(saved?.exchangeContext == "OT에서 교환")
        #expect(repository.savedCards.count == 1)
        #expect(repository.savedCards.first?.id == "CARD-PEER")
    }

    @Test("저장 실패는 그대로 전파한다")
    func propagatesSaveError() async throws {
        let repository = MockReceivedCardRepository()
        repository.saveError = MockError.notStubbed
        let sut = SaveReceivedCardUseCase(repository: repository)
        let payload = try makePayload()

        await #expect(throws: MockError.self) {
            _ = try await sut.execute(
                payload: payload,
                ownerMemberId: "42",
                exchangeContext: nil,
                exchangeMethod: .qrLink
            )
        }
    }

    @Test("내 명함은 명함첩에 넣지 않는다 — 자기 QR 스캔·같은 계정 두 대 교환")
    func skipsOwnCard() async throws {
        let repository = MockReceivedCardRepository()
        let sut = SaveReceivedCardUseCase(repository: repository)

        let saved = try await sut.execute(
            payload: try makePayload(),
            ownerMemberId: "7",
            exchangeContext: nil,
            exchangeMethod: .nearby
        )

        #expect(saved == nil)
        #expect(repository.savedCards.isEmpty)
    }

    /// cardLink 가 안 읽히면 `memberId` 가 빈 문자열이 된다. 그때 내 id 까지 비어 있으면
    /// **모르는 상대를 나 자신으로 오인해 통째로 버린다.** 빈 값끼리는 비교하지 않는다.
    @Test("memberId를 못 읽은 명함은 거르지 않는다")
    func keepsCardWithUnreadableMemberId() async throws {
        let repository = MockReceivedCardRepository()
        let sut = SaveReceivedCardUseCase(repository: repository)
        let payload = try ExchangePayload(
            cardID: "CARD-PEER", name: "상대", nickname: "상대닉", part: "DESIGN",
            generation: "11", university: "중앙대학교", email: nil, github: nil,
            linkedIn: nil, blog: nil, avatarURL: nil, cardLink: "not-a-link"
        )

        let saved = try await sut.execute(
            payload: payload,
            ownerMemberId: "",
            exchangeContext: nil,
            exchangeMethod: .qrLink
        )

        #expect(saved?.profile.memberId == "")
        #expect(repository.savedCards.count == 1)
    }

    /// v1 교환 페이로드는 기수·파트 필드 자체가 없어 빈 문자열로 복원된다. 그대로 저장하면
    /// 명함첩에 「운영진 · 기수 없음」 한 장이 남는다 (#1223).
    @Test("기수가 빈 명함은 저장 전에 걸러 낸다")
    func rejectsCardWithoutGeneration() async throws {
        let repository = MockReceivedCardRepository()
        let sut = SaveReceivedCardUseCase(repository: repository)
        let payload = try ExchangePayload(
            cardID: "CARD-PEER", name: "상대", nickname: "상대닉", part: "",
            generation: "", university: "중앙대학교", email: nil, github: nil,
            linkedIn: nil, blog: nil, avatarURL: nil, cardLink: "umc://card/7"
        )

        await #expect(throws: AppError.self) {
            _ = try await sut.execute(
                payload: payload,
                ownerMemberId: "42",
                exchangeContext: nil,
                exchangeMethod: .nearby
            )
        }
        #expect(repository.savedCards.isEmpty)
    }

    @Test("딥링크 경로도 내 명함이면 저장하지 않는다")
    func skipsOwnCardOnDeepLinkPath() async throws {
        let repository = MockReceivedCardRepository()
        let sut = SaveReceivedCardUseCase(repository: repository)
        let mine = MyCard(
            memberId: "7", name: "나", nickname: "내닉", part: .front(type: .ios),
            generation: "12", university: "한양대학교", email: nil, github: nil,
            linkedIn: nil, blog: nil, avatarURL: nil
        )

        let saved = try await sut.execute(
            card: mine,
            cardID: "CARD-7",
            ownerMemberId: "7",
            exchangeContext: nil,
            exchangeMethod: .qrLink
        )

        #expect(saved == nil)
        #expect(repository.savedCards.isEmpty)
    }

    @Test("교환 방식은 저장된 명함에 그대로 남는다")
    func keepsExchangeMethod() async throws {
        let repository = MockReceivedCardRepository()
        let sut = SaveReceivedCardUseCase(repository: repository)

        let saved = try await sut.execute(
            payload: try makePayload(),
            ownerMemberId: "42",
            exchangeContext: nil,
            exchangeMethod: .nearby
        )

        #expect(saved?.exchangeMethod == .nearby)
        #expect(repository.savedCards.first?.exchangeMethod == .nearby)
    }
}
