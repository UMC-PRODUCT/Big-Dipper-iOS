//
//  FetchPeerCardUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by euijjang97 on 8/28/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import BusinessCardDomain

/// QR 딥링크(`umc://card/{memberId}`)로 스캔한 상대 명함 조회.
///
/// 딥링크에는 식별자밖에 없어서 이 UseCase 가 실패하면 스캔 화면이 그대로 멈춘다.
/// 위임이 얇은 만큼 **무엇을 그대로 통과시키는지**가 계약의 전부다.
@Suite("FetchPeerCardUseCase — memberId 조회 위임")
struct FetchPeerCardUseCaseTests {

    private func makeCard(memberId: String = "7") -> MyCard {
        MyCard(
            memberId: memberId, name: "상대", nickname: "상대닉",
            part: .front(type: .ios), generation: "11", university: "중앙대학교",
            email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
        )
    }

    @Test("조회한 명함을 그대로 돌려준다")
    func returnsFetchedCard() async throws {
        let repository = MockPeerCardRepository()
        repository.fetchCardResult = .success(makeCard())
        let sut = FetchPeerCardUseCase(repository: repository)

        let card = try await sut.execute(memberId: "7")

        #expect(card.memberId == "7")
        #expect(card.name == "상대")
    }

    @Test("딥링크에서 파싱한 memberId를 그대로 넘긴다")
    func passesMemberIdThrough() async throws {
        let repository = MockPeerCardRepository()
        repository.fetchCardResult = .success(makeCard(memberId: "1024"))
        let sut = FetchPeerCardUseCase(repository: repository)

        _ = try await sut.execute(memberId: "1024")

        #expect(repository.requestedMemberIds == ["1024"])
    }

    /// 실패를 삼키고 빈 명함을 돌려주면 스캔 화면이 「이름 없는 명함」을 그려 버린다.
    @Test("조회 실패는 그대로 전파한다")
    func propagatesFetchError() async {
        let repository = MockPeerCardRepository()
        repository.fetchCardResult = .failure(MockError.notStubbed)
        let sut = FetchPeerCardUseCase(repository: repository)

        await #expect(throws: MockError.self) {
            _ = try await sut.execute(memberId: "7")
        }
    }

    /// 서버가 모르는 파트/기수를 내려도 조회 자체는 성공해야 한다.
    /// 값 판단은 위(화면)에서 하고, 여기서는 거르지 않는다.
    @Test("모르는 파트·빈 기수가 실린 명함도 막지 않는다")
    func passesThroughUnknownPartAndGeneration() async throws {
        let repository = MockPeerCardRepository()
        repository.fetchCardResult = .success(
            MyCard(
                memberId: "7", name: "상대", nickname: "", part: .admin,
                generation: "", university: "", email: nil, github: nil,
                linkedIn: nil, blog: nil, avatarURL: nil, partRaw: "RUST"
            )
        )
        let sut = FetchPeerCardUseCase(repository: repository)

        let card = try await sut.execute(memberId: "7")

        #expect(card.partAPIValue == "RUST", "모르는 파트를 ADMIN 으로 바꿔 퍼뜨리지 않는다")
        #expect(card.generation == "")
    }

    /// 딥링크 파싱이 실패해 빈 문자열이 오는 경로. 여기서 막지 않고 그대로 넘겨
    /// 서버 응답(404)으로 판정한다 — 로컬 규칙과 서버 규칙이 갈라지면 진단이 어려워진다.
    @Test("빈 memberId도 저장소 판단에 맡긴다")
    func leavesEmptyMemberIdToRepository() async {
        let repository = MockPeerCardRepository()
        let sut = FetchPeerCardUseCase(repository: repository)

        _ = try? await sut.execute(memberId: "")

        #expect(repository.requestedMemberIds == [""])
    }
}
