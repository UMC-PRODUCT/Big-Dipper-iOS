//
//  MyCardPeerPreviewTests.swift
//  BusinessCardDomainTests
//
//  Created by JEONG on 8/28/26.
//

import Foundation
import Testing
import UMCFoundation
import CoreNearbyExchange
@testable import BusinessCardDomain

/// 발견 목록 미리보기의 **프라이버시 계약**.
///
/// `PeerPreview` 는 명함 본체와 결정적으로 다르다 — 상대가 「받기」를 누르기 **전에**,
/// 동의 없이 근처 모두에게 자동으로 뿌려진다. 그래서 여기 실리는 필드는
/// "목록 행 한 줄을 그리는 데 꼭 필요한가"만으로 정해진다.
///
/// 이 계약이 깨지는 경로는 대개 새 필드 추가다. ``MyCard`` 에 연락처가 하나 늘고
/// ``MyCard/toPeerPreview()`` 에 무심코 딸려 들어가면, 컴파일도 되고 화면도 멀쩡하다.
/// 그래서 필드 단위 검사와 **직렬화 결과 검사**를 같이 둔다 — 후자는 아직 존재하지 않는
/// 필드까지 잡는다.
@Suite("MyCard.toPeerPreview — 동의 전 노출 범위")
struct MyCardPeerPreviewTests {

    /// 연락처가 전부 채워진 명함. 미리보기가 무엇을 **버리는지** 보려면 원본이 꽉 차야 한다.
    private let card = MyCard(
        memberId: "42", name: "정의찬", nickname: "제옹",
        part: .front(type: .ios), generation: "12", university: "한양대학교",
        email: "one@umc.dev", github: "github.com/UMC-PRODUCT",
        linkedIn: "linkedin.com/in/umc", blog: "umc.dev/blog",
        avatarURL: "https://cdn.umc.it.kr/a.png"
    )

    @Test("목록 한 줄에 필요한 값만 싣는다")
    func carriesOnlyRowFields() {
        let preview = card.toPeerPreview()

        #expect(preview.name == "정의찬")
        #expect(preview.nickname == "제옹")
        #expect(preview.part == UMCPartType.front(type: .ios).apiValue)
        #expect(preview.generation == "12")
        #expect(preview.avatarURL == "https://cdn.umc.it.kr/a.png")
    }

    /// 필드를 이름으로 하나씩 세는 대신 직렬화 결과를 통째로 본다.
    /// 나중에 누가 `phone` 을 끼워 넣어도 이 검사에 걸린다.
    @Test("이메일·깃허브·링크드인·블로그는 실리지 않는다")
    func dropsContactDetails() throws {
        let preview = card.toPeerPreview()

        let json = try #require(String(data: try JSONEncoder().encode(preview), encoding: .utf8))

        #expect(!json.contains("one@umc.dev"))
        #expect(!json.contains("github.com"))
        #expect(!json.contains("linkedin.com"))
        #expect(!json.contains("umc.dev/blog"))
    }

    /// 학교·memberId 도 마찬가지다. 미리보기만으로 상대를 특정하거나 서버에서
    /// 조회할 수 있으면 「보기 전 단계」라는 구분이 사라진다.
    @Test("소속 학교와 memberId 도 실리지 않는다")
    func dropsIdentifyingFields() throws {
        let preview = card.toPeerPreview()

        let json = try #require(String(data: try JSONEncoder().encode(preview), encoding: .utf8))

        #expect(!json.contains("한양대학교"))
        #expect(!json.contains("\"42\""))
    }

    @Test("명함 본체에는 연락처가 그대로 실린다 — 미리보기와 담기는 것이 다르다")
    func fullPayloadStillCarriesContacts() throws {
        let payload = try card.toExchangePayload()

        #expect(payload.email == "one@umc.dev")
        #expect(payload.github == "github.com/UMC-PRODUCT")
        #expect(payload.university == "한양대학교")
    }

    @Test("연락처가 비어 있어도 미리보기 필드는 그대로 채워진다")
    func worksWithoutContacts() {
        let bare = MyCard(
            memberId: "42", name: "정의찬", nickname: "제옹",
            part: .front(type: .ios), generation: "12", university: "한양대학교",
            email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
        )

        let preview = bare.toPeerPreview()

        #expect(preview.name == "정의찬")
        #expect(preview.avatarURL == nil)
    }

    /// **알려진 결함 — 프로덕션 코드는 이번 PR 에서 고치지 않는다.**
    ///
    /// ``MyCard/toExchangePayload(cardID:)`` 는 ``MyCard/partAPIValue`` 를 쓰는데
    /// ``MyCard/toPeerPreview()`` 만 `part.apiValue` 를 쓴다. 그래서 우리가 모르는 파트가
    /// `partRaw` 에 담겨 와도 미리보기에서는 `ADMIN` 으로 바뀐다 — 발견 목록에서는
    /// 「운영진」, 명함을 받고 나면 원래 파트로 바뀌는 셈이다.
    ///
    /// `partAPIValue` 의 규칙("우리가 못 읽었다는 이유로 남의 값을 ADMIN 으로 바꿔
    /// 퍼뜨리면 안 된다")과 정면으로 어긋나고, 같은 규칙을 페이로드 쪽에서는
    /// `MyCardExchangePayloadTests.unknownPartRoundTripsUnchanged` 가 이미 고정하고 있다.
    /// 고치려면 한 단어(`part.apiValue` → `partAPIValue`)면 되지만, 이 이슈(#1240)는
    /// 테스트 보강 범위라 결함을 여기 고정만 해 둔다.
    @Test("못 읽은 파트는 미리보기에도 원본으로 실려야 한다")
    func unknownPartShouldSurviveInPreview() {
        let unknown = MyCard(
            memberId: "42", name: "정의찬", nickname: "제옹",
            part: .admin, generation: "12", university: "한양대학교",
            email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil,
            partRaw: "RUST"
        )

        withKnownIssue("toPeerPreview 가 partRaw 를 버리고 ADMIN 으로 바꾼다") {
            #expect(unknown.toPeerPreview().part == "RUST")
        }
    }
}
